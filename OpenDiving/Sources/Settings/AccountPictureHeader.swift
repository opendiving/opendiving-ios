import OpenDivingKit
import SwiftUI

/// *Account*'s head: the profile picture, centred, over *Edit photo*, whose menu takes a photo,
/// chooses one and, once there is a picture, adjusts its crop or deletes it. Each is sent as soon
/// as it is chosen; a refusal puts the stored picture back and says why.
struct AccountPictureHeader: View {
  let model: PictureFieldModel

  @State private var picker = PicturePicker(kind: .avatar)
  @State private var confirmingDelete = false
  @State private var failure: String?

  private static let side: CGFloat = 112

  private var busy: Bool { picker.preparing || model.opening != nil || model.isSending }

  var body: some View {
    VStack(spacing: 10) {
      PicturePreview(model: model, width: Self.side)
        .overlay {
          if busy {
            Circle()
              .fill(.ultraThinMaterial)
              .overlay { BubbleSpinner() }
          }
        }
      Menu {
        if CameraPicker.isAvailable {
          Button("Take photo", systemImage: "camera") { picker.takingPhoto = true }
        }
        Button("Choose photo", systemImage: "photo.on.rectangle") { picker.choosingPhoto = true }
        if model.hasPicture {
          if model.canAdjust {
            Button("Adjust", systemImage: "crop") {
              Task { await picker.open(.adjust, on: model) }
            }
          }
          Button("Delete", systemImage: "trash", role: .destructive) { confirmingDelete = true }
        }
      } label: {
        Text("Edit photo")
      }
      .buttonStyle(.borderless)
      .disabled(busy)
    }
    .frame(maxWidth: .infinity)
    .picturePicker(picker, confirm: PictureKind.cropSave) { save($0) }
    .confirmationDialog(
      "Delete your profile picture?", isPresented: $confirmingDelete, titleVisibility: .visible
    ) {
      Button("Delete", role: .destructive) { save(.remove) }
    }
    .alert(
      "Error", isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })
    ) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(failure ?? "")
    }
  }

  private func save(_ edit: PictureEdit) {
    Task { failure = await model.save(edit) }
  }
}

#Preview {
  let session = Session.stub(transport: StubTransport(routes: [:]))
  List {
    AccountPictureHeader(model: PictureFieldModel(kind: .avatar, session: session))
      .listRowBackground(Color.clear)
  }
}
