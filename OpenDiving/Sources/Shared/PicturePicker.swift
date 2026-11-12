import OpenDivingKit
import SwiftUI
import UIKit

/// The way to a crop that a picture's hosts share: the camera, the photo library, or an original
/// fetched to adjust or copy, made ready off the main actor and refused here when the server
/// would refuse it. A host sets ``takingPhoto`` or ``choosingPhoto``, or calls ``open(_:on:)``,
/// and attaches ``SwiftUI/View/picturePicker(_:confirm:onCropped:)``, which presents the rest.
@Observable
final class PicturePicker {
  let kind: PictureKind
  var takingPhoto = false
  var choosingPhoto = false
  private(set) var preparing = false
  var cropping: PictureCropping?
  var refusal: PictureRefusal?

  init(kind: PictureKind) {
    self.kind = kind
  }

  /// Runs `preparation` off the main actor and opens the crop on what it made.
  func prepare(
    _ preparation:
      @escaping @Sendable (PictureKind) -> Result<PicturePreparer.Prepared, PictureRefusal>
  ) async {
    preparing = true
    defer { preparing = false }
    let kind = kind
    switch await Task.detached(operation: { preparation(kind) }).value {
    case .success(let prepared): cropping = prepared.cropping
    case .failure(let refused): refusal = refused
    }
  }

  /// Opens the crop on what `model` has for `opening`, fetching it where the phone has none.
  func open(_ opening: PictureFieldModel.Opening, on model: PictureFieldModel) async {
    switch await model.open(opening) {
    case .failure(let refused):
      refusal = refused
    case .success(.cropping(let pending)):
      cropping = pending
    case .success(.rendition(let data)):
      await prepare { PicturePreparer.prepare(data, kind: $0) }
    case .success(.bytes(let data, let purpose, let initial)):
      guard let image = UIImage(data: data) else {
        refusal = .unreadable
        return
      }
      let source = PictureSource(
        data: data, width: Int((image.size.width * image.scale).rounded()),
        height: Int((image.size.height * image.scale).rounded()))
      cropping = PictureCropping(purpose: purpose, source: source, initial: initial)
    }
  }
}

extension View {
  /// Presents what `picker` is asked for — the camera, the library, the crop with `confirm` as
  /// its confirming action, a refusal — and hands the chosen crop to `onCropped` as an edit.
  func picturePicker(
    _ picker: PicturePicker, confirm: String, onCropped: @escaping (PictureEdit) -> Void
  ) -> some View {
    modifier(PicturePicking(picker: picker, confirm: confirm, onCropped: onCropped))
  }
}

private struct PicturePicking: ViewModifier {
  @Bindable var picker: PicturePicker
  let confirm: String
  let onCropped: (PictureEdit) -> Void

  func body(content: Content) -> some View {
    content
      .fullScreenCover(isPresented: $picker.takingPhoto) {
        CameraPicker { taken in
          picker.takingPhoto = false
          if let taken {
            Task { await picker.prepare { PicturePreparer.prepare(taken, kind: $0) } }
          }
        }
        .ignoresSafeArea()
      }
      .photoLibraryPick(isPresented: $picker.choosingPhoto) { data in
        guard let data else {
          picker.refusal = .unreadable
          return
        }
        Task { await picker.prepare { PicturePreparer.prepare(data, kind: $0) } }
      }
      .sheet(item: $picker.cropping) { cropping in
        PictureCropSheet(kind: picker.kind, cropping: cropping, confirm: confirm) { area in
          onCropped(cropping.edit(cropping: area, kind: picker.kind))
        }
      }
      .alert(
        picker.refusal?.title ?? "",
        isPresented: Binding(
          get: { picker.refusal != nil }, set: { if !$0 { picker.refusal = nil } })
      ) {
        Button("OK", role: .cancel) {}
      } message: {
        Text(picker.refusal?.message ?? "")
      }
  }
}
