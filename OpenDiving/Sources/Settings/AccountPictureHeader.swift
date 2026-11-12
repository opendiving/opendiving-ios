import OpenDivingKit
import SwiftUI

/// *Account*'s head: the profile picture, centred, over *Edit photo* — *Add photo* while there is
/// none — both opening the menu that takes a photo, chooses one and, once there is a picture,
/// adjusts its crop or deletes it. Each is sent as soon as it is chosen; a refusal puts the
/// stored picture back and says why.
struct AccountPictureHeader: View {
  let model: PictureFieldModel

  @State private var picker = PicturePicker(kind: .avatar)
  @State private var confirmingDelete = false
  @State private var failure: String?

  private static let side: CGFloat = 112

  private var busy: Bool { picker.preparing || model.opening != nil || model.isSending }

  var body: some View {
    VStack(spacing: 10) {
      Menu {
        menuItems
      } label: {
        PicturePreview(model: model, width: Self.side, showsPending: false)
          // The old picture, blurred, while the new one is on its way; the new one, sharp, once
          // the server has it.
          .blur(radius: busy ? 8 : 0, opaque: true)
          .clipShape(Circle())
          .overlay {
            if busy {
              Circle()
                .fill(.black.opacity(0.25))
                .overlay { BubbleSpinner(style: .white) }
                .transition(.opacity)
            }
          }
          .animation(.easeInOut(duration: 0.35), value: busy)
      }
      .buttonStyle(.plain)
      .disabled(busy)
      Menu {
        menuItems
      } label: {
        Text(model.hasPicture ? "Edit photo" : "Add photo")
          .bold()
      }
      .buttonStyle(.borderless)
      .accentRow()
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

  @ViewBuilder private var menuItems: some View {
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
