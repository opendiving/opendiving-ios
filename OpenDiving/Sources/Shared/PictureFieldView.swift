import OpenDivingKit
import PhotosUI
import SwiftUI
import UIKit

/// One of the account's pictures as a field of its form, as the web's `PictureSlot` draws it:
/// what it holds or what saving will do to it, *Upload* or *Replace* from the camera or the photo
/// library, *Adjust*, *Use profile picture* for the portrait, and the bin. A pick the server
/// would refuse is refused here, before the crop opens and before anything is sent; nothing is
/// sent from here at all — the form sends the edit after its fields.
struct PictureFieldView: View {
  let model: PictureFieldModel

  @State private var takingPhoto = false
  @State private var choosingPhoto = false
  @State private var photo: PhotosPickerItem?
  @State private var preparing = false
  @State private var cropping: PictureCropping?
  @State private var refusal: PictureRefusal?
  @State private var pending: UIImage?
  @State private var stored: UIImage?

  /// One width for both pictures, so the two forms line up.
  private static let width: CGFloat = 120

  private var kind: PictureKind { model.kind }
  private var busy: Bool { preparing || model.opening != nil || model.isSending }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(kind.heading)
        .font(.subheadline.weight(.medium))
      HStack(alignment: .top, spacing: 16) {
        picture
          .frame(width: Self.width, height: Self.width / kind.aspect)
          .clipShape(shape)
        VStack(alignment: .leading, spacing: 8) {
          controls
        }
        .buttonStyle(.bordered)
        .disabled(busy)
      }
      Text(model.caption)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .padding(.vertical, 4)
    .task(id: model.storedSha) { await model.loadStored() }
    .onChange(of: model.storedData, initial: true) { _, data in
      stored = data.flatMap(UIImage.init(data:))
    }
    .onChange(of: model.revision, initial: true) {
      pending = model.shown?.source.flatMap { UIImage(data: $0.data) }
    }
    .fullScreenCover(isPresented: $takingPhoto) {
      CameraPicker { taken in
        takingPhoto = false
        if let taken { Task { await prepare { PicturePreparer.prepare(taken, kind: $0) } } }
      }
      .ignoresSafeArea()
    }
    .photosPicker(isPresented: $choosingPhoto, selection: $photo, matching: .images)
    .onChange(of: photo) { _, item in
      guard let item else { return }
      photo = nil
      Task { await load(item) }
    }
    .sheet(item: $cropping) { cropping in
      PictureCropSheet(kind: kind, cropping: cropping) { area in
        model.set(cropping.edit(cropping: area, kind: kind))
      }
    }
    .alert(
      refusal?.title ?? "",
      isPresented: Binding(get: { refusal != nil }, set: { if !$0 { refusal = nil } })
    ) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(refusal?.message ?? "")
    }
  }

  private var shape: AnyShape {
    kind == .avatar ? AnyShape(Circle()) : AnyShape(RoundedRectangle(cornerRadius: 8))
  }

  @ViewBuilder private var picture: some View {
    if let crop = model.shown?.crop, let pending {
      CroppedPicture(image: pending, crop: crop, width: Self.width)
        .accessibilityLabel("New \(kind.label)")
    } else if model.showsStored, let stored {
      Image(uiImage: stored)
        .resizable()
        .scaledToFill()
        .accessibilityLabel("Your \(kind.label)")
    } else if kind == .avatar {
      UserAvatarView(initials: model.initials, picture: nil, side: Self.width)
        .background(Color(.secondarySystemBackground))
    } else {
      ZStack {
        Color(.secondarySystemBackground)
        Image(systemName: "person.crop.square")
          .font(.largeTitle)
          .foregroundStyle(.secondary)
      }
      .accessibilityElement()
      .accessibilityLabel(model.showsStored ? "Your \(kind.label)" : "No \(kind.label)")
    }
  }

  @ViewBuilder private var controls: some View {
    Menu {
      if CameraPicker.isAvailable {
        Button("Take Photo", systemImage: "camera") { takingPhoto = true }
      }
      Button("Photo Library", systemImage: "photo.on.rectangle") { choosingPhoto = true }
    } label: {
      HStack(spacing: 6) {
        if preparing {
          BubbleSpinner()
        } else {
          Image(
            systemName: model.primaryLabel == "Upload"
              ? "square.and.arrow.up" : "arrow.2.squarepath")
        }
        Text(model.primaryLabel)
      }
    }
    if model.canAdjust {
      Button {
        Task { await open(.adjust) }
      } label: {
        HStack(spacing: 6) {
          if model.opening == .adjust { BubbleSpinner() } else { Image(systemName: "crop") }
          Text("Adjust")
        }
      }
    }
    if model.canCopy {
      Button {
        Task { await open(.copy) }
      } label: {
        HStack(spacing: 6) {
          if model.opening == .copy { BubbleSpinner() }
          Text("Use profile picture")
        }
      }
    }
    if let bin = model.bin {
      Button {
        model.pressBin()
      } label: {
        Image(systemName: bin == .keep ? "arrow.uturn.backward" : "trash")
      }
      .accessibilityLabel(bin.label(kind))
    }
  }

  private func load(_ item: PhotosPickerItem) async {
    guard let data = try? await item.loadTransferable(type: Data.self) else {
      refusal = .unreadable
      return
    }
    await prepare { PicturePreparer.prepare(data, kind: $0) }
  }

  /// Runs `preparation` off the main actor and opens the crop on what it made.
  private func prepare(
    _ preparation:
      @escaping @Sendable (PictureKind) -> Result<
        PicturePreparer.Prepared, PictureRefusal
      >
  ) async {
    preparing = true
    defer { preparing = false }
    let kind = kind
    switch await Task.detached(operation: { preparation(kind) }).value {
    case .success(let prepared): cropping = prepared.cropping
    case .failure(let refused): refusal = refused
    }
  }

  private func open(_ opening: PictureFieldModel.Opening) async {
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

/// A pending crop over its whole upright picture, drawn by placing the picture inside the frame
/// rather than by cutting it: the preview shows exactly the rectangle the server will be sent.
private struct CroppedPicture: View {
  let image: UIImage
  let crop: PictureCrop
  let width: CGFloat

  var body: some View {
    let scale = width / CGFloat(crop.width)
    Color.clear
      .overlay(alignment: .topLeading) {
        Image(uiImage: image)
          .resizable()
          .frame(
            width: image.size.width * image.scale * scale,
            height: image.size.height * image.scale * scale
          )
          .offset(x: -CGFloat(crop.x) * scale, y: -CGFloat(crop.y) * scale)
      }
      .clipped()
  }
}

#Preview {
  let session = Session.stub(transport: StubTransport(routes: [:]))
  Form {
    PictureFieldView(model: PictureFieldModel(kind: .avatar, session: session))
    PictureFieldView(model: PictureFieldModel(kind: .portrait, session: session))
  }
}
