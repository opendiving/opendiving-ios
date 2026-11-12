import OpenDivingKit
import SwiftUI

/// One of the account's pictures as a field of its form, as the web's `PictureSlot` draws it:
/// what it holds or what saving will do to it, *Upload* or *Replace* from the camera or the photo
/// library, *Adjust*, *Use profile picture* for the portrait, and the bin. A pick the server
/// would refuse is refused before the crop opens and before anything is sent; nothing is sent
/// from here at all — the form sends the edit after its fields.
struct PictureFieldView: View {
  let model: PictureFieldModel

  @State private var picker: PicturePicker

  /// One width for both pictures, so the two forms line up.
  private static let width: CGFloat = 120

  init(model: PictureFieldModel) {
    self.model = model
    _picker = State(initialValue: PicturePicker(kind: model.kind))
  }

  private var busy: Bool { picker.preparing || model.opening != nil || model.isSending }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(model.kind.heading)
        .font(.subheadline.weight(.medium))
      HStack(alignment: .top, spacing: 16) {
        PicturePreview(model: model, width: Self.width)
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
    .picturePicker(picker, confirm: PictureKind.cropConfirm) { model.set($0) }
  }

  @ViewBuilder private var controls: some View {
    Menu {
      if CameraPicker.isAvailable {
        Button("Take Photo", systemImage: "camera") { picker.takingPhoto = true }
      }
      Button("Photo Library", systemImage: "photo.on.rectangle") { picker.choosingPhoto = true }
    } label: {
      HStack(spacing: 6) {
        if picker.preparing {
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
        Task { await picker.open(.adjust, on: model) }
      } label: {
        HStack(spacing: 6) {
          if model.opening == .adjust { BubbleSpinner() } else { Image(systemName: "crop") }
          Text("Adjust")
        }
      }
    }
    if model.canCopy {
      Button {
        Task { await picker.open(.copy, on: model) }
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
      .accessibilityLabel(bin.label(model.kind))
    }
  }
}

#Preview {
  let session = Session.stub(transport: StubTransport(routes: [:]))
  Form {
    PictureFieldView(model: PictureFieldModel(kind: .portrait, session: session))
  }
}
