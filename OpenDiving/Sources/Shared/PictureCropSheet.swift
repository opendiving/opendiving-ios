import OpenDivingKit
import SwiftUI
import UIKit

/// The web's *Adjust Your Photo*: the whole upright picture under a frame of the picture's shape
/// — a circle for the profile picture, 7:9 for the portrait — dragged to move and pinched or slid
/// to zoom. Nothing is sent from here: the rectangle chosen becomes the form's pending edit.
struct PictureCropSheet: View {
  let kind: PictureKind
  let cropping: PictureCropping
  let onCropped: (CropFrame.Area) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var frame: CropFrame
  @State private var dragStart: (x: Double, y: Double)?
  @State private var zoomStart: Double?
  @State private var frameWidth: CGFloat = 1
  private let image: UIImage?

  init(kind: PictureKind, cropping: PictureCropping, onCropped: @escaping (CropFrame.Area) -> Void)
  {
    self.kind = kind
    self.cropping = cropping
    self.onCropped = onCropped
    image = UIImage(data: cropping.source.data)
    let (width, height) = (Double(cropping.source.width), Double(cropping.source.height))
    _frame = State(
      initialValue: cropping.initial.map {
        CropFrame(aspect: kind.aspect, imageWidth: width, imageHeight: height, showing: $0.area)
      } ?? CropFrame(aspect: kind.aspect, imageWidth: width, imageHeight: height))
  }

  var body: some View {
    NavigationStack {
      VStack(alignment: .leading, spacing: 20) {
        Text(kind.cropDescription)
          .font(.subheadline)
          .foregroundStyle(.secondary)
        cropper
        VStack(alignment: .leading, spacing: 8) {
          Label("Zoom", systemImage: "plus.magnifyingglass")
            .font(.subheadline.weight(.medium))
          Slider(
            value: Binding(get: { frame.zoom }, set: { frame.setZoom($0) }),
            in: CropFrame.minZoom...frame.maxZoom
          ) {
            Text("Zoom")
          }
        }
        Spacer()
      }
      .padding()
      .navigationTitle(PictureKind.cropTitle)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          ToolbarConfirmButton(title: PictureKind.cropConfirm) {
            onCropped(frame.area)
            dismiss()
          }
        }
      }
    }
  }

  private var cropper: some View {
    let area = frame.area
    return Color.black
      .aspectRatio(kind.aspect, contentMode: .fit)
      .frame(maxWidth: .infinity)
      .onGeometryChange(for: CGFloat.self) {
        $0.size.width
      } action: {
        frameWidth = max($0, 1)
      }
      .overlay(alignment: .topLeading) {
        if let image {
          let scale = frameWidth / area.width
          Image(uiImage: image)
            .resizable()
            .frame(width: frame.imageWidth * scale, height: frame.imageHeight * scale)
            .offset(x: -area.x * scale, y: -area.y * scale)
        }
      }
      .overlay {
        if kind == .avatar {
          // Only the circle is shown, so what falls outside it is dimmed.
          ZStack {
            Color.black.opacity(0.5)
            Circle().blendMode(.destinationOut)
          }
          .compositingGroup()
          .allowsHitTesting(false)
        }
      }
      .clipShape(RoundedRectangle(cornerRadius: 10))
      .contentShape(Rectangle())
      .gesture(drag.simultaneously(with: pinch))
      .accessibilityLabel("The crop's frame")
  }

  private var drag: some Gesture {
    DragGesture()
      .onChanged { value in
        let start = dragStart ?? (frame.centerX, frame.centerY)
        dragStart = start
        let pixels = frame.area.width / frameWidth
        frame.center(
          x: start.x - value.translation.width * pixels,
          y: start.y - value.translation.height * pixels)
      }
      .onEnded { _ in dragStart = nil }
  }

  private var pinch: some Gesture {
    MagnifyGesture()
      .onChanged { value in
        let start = zoomStart ?? frame.zoom
        zoomStart = start
        frame.setZoom(start * value.magnification)
      }
      .onEnded { _ in zoomStart = nil }
  }
}

#Preview {
  PictureCropSheet(
    kind: .avatar,
    cropping: PictureCropping(
      purpose: .adjust,
      source: PictureSource(
        data: UIImage(systemName: "person.fill")?.pngData() ?? Data(), width: 20, height: 19))
  ) { _ in }
}
