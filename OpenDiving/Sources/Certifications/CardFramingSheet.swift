import OpenDivingKit
import SwiftUI
import UIKit

/// The web's *Frame Your Card*: the picked picture under a frame of the card's shape, dragged to
/// move and pinched or slid to zoom. Everything inside the frame is kept, as a JPEG no wider than
/// the card is drawn at.
struct CardFramingSheet: View {
  let image: UIImage
  let onFramed: (Data) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var crop: CertificationCardCrop
  /// The frame's centre as the gesture under way found it.
  @State private var dragStart: (x: Double, y: Double)?
  @State private var zoomStart: Double?
  @State private var frameWidth: CGFloat = 1

  init(image: UIImage, onFramed: @escaping (Data) -> Void) {
    self.image = image
    self.onFramed = onFramed
    _crop = State(
      initialValue: CertificationCardCrop(
        imageWidth: image.size.width, imageHeight: image.size.height))
  }

  static let title = "Frame Your Card"
  static let description =
    "Drag to move, pinch or use the slider to zoom. Everything inside the frame is saved, and that is the shape cards are shown in."

  var body: some View {
    NavigationStack {
      VStack(alignment: .leading, spacing: 20) {
        Text(Self.description)
          .font(.subheadline)
          .foregroundStyle(.secondary)
        cropper
        VStack(alignment: .leading, spacing: 8) {
          Label("Zoom", systemImage: "plus.magnifyingglass")
            .font(.subheadline.weight(.medium))
          Slider(
            value: Binding(get: { crop.zoom }, set: { crop.setZoom($0) }),
            in: CertificationCardCrop.minZoom...CertificationCardCrop.maxZoom
          ) {
            Text("Zoom")
          }
        }
        Spacer()
      }
      .padding()
      .navigationTitle(Self.title)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          ToolbarConfirmButton(title: "Use this crop") {
            guard let data = render() else { return }
            onFramed(data)
            dismiss()
          }
        }
      }
    }
  }

  private var cropper: some View {
    let area = crop.area
    return Color.black
      .aspectRatio(CertificationCardCrop.aspect, contentMode: .fit)
      .frame(maxWidth: .infinity)
      .onGeometryChange(for: CGFloat.self) {
        $0.size.width
      } action: {
        frameWidth = max($0, 1)
      }
      .overlay(alignment: .topLeading) {
        let scale = frameWidth / area.width
        Image(uiImage: image)
          .resizable()
          .frame(width: image.size.width * scale, height: image.size.height * scale)
          .offset(x: -area.x * scale, y: -area.y * scale)
      }
      .clipShape(RoundedRectangle(cornerRadius: 10))
      .contentShape(Rectangle())
      .gesture(drag.simultaneously(with: pinch))
      .accessibilityLabel("The card's frame")
  }

  private var drag: some Gesture {
    DragGesture()
      .onChanged { value in
        let start = dragStart ?? (crop.centerX, crop.centerY)
        dragStart = start
        let pixels = crop.area.width / frameWidth
        crop.center(
          x: start.x - value.translation.width * pixels,
          y: start.y - value.translation.height * pixels)
      }
      .onEnded { _ in dragStart = nil }
  }

  private var pinch: some Gesture {
    MagnifyGesture()
      .onChanged { value in
        let start = zoomStart ?? crop.zoom
        zoomStart = start
        crop.setZoom(start * value.magnification)
      }
      .onEnded { _ in zoomStart = nil }
  }

  /// The framed part, drawn at the kept size.
  private func render() -> Data? {
    let area = crop.area
    let size = crop.exportSize
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    let scale = size.width / area.width
    let renderer = UIGraphicsImageRenderer(
      size: CGSize(width: size.width, height: size.height), format: format)
    return renderer.jpegData(withCompressionQuality: 0.9) { _ in
      image.draw(
        in: CGRect(
          x: -area.x * scale, y: -area.y * scale, width: image.size.width * scale,
          height: image.size.height * scale))
    }
  }
}

#Preview {
  CardFramingSheet(image: UIImage(systemName: "creditcard")!) { _ in }
}
