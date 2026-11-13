import OpenDivingKit
import SwiftUI

/// The passkeys, each renamed in its row or removed after a confirmation. Nothing here adds
/// one.
struct PasskeysSection: View {
  let model: PasskeysModel

  var body: some View {
    if model.isShown {
      Section {
        OptionalListStatus(
          list: model.list, failed: PasskeysModel.loadFailed, loading: "Loading passkeys…")
        ForEach(model.list.value ?? []) { passkey in
          if model.rename.editing == passkey.uuid {
            InlineRenameRow(
              original: passkey.name, draft: Bindable(model.rename).draft,
              canSave: model.rename.canSave, isSaving: model.rename.isSaving
            ) {
              Task { await model.saveRename() }
            } stop: {
              model.rename.stop()
            }
          } else {
            row(passkey)
          }
        }
      } header: {
        Text("Passkeys")
      } footer: {
        VStack(alignment: .leading, spacing: 8) {
          if let failure = model.rename.failure ?? model.removeFailure {
            FieldMessage(failure)
          }
          Text(PasskeysModel.description)
          Text(PasskeysModel.addedOnTheWeb)
        }
      }
    }
  }

  private func row(_ passkey: PasskeyRead) -> some View {
    HStack(spacing: 12) {
      VStack(alignment: .leading, spacing: 4) {
        FlowLayout(spacing: 6) {
          Text(passkey.name)
          if passkey.backedUp {
            BadgeView(PasskeysModel.synced) { EmptyView() }
          }
        }
        Text(PasskeysModel.details(passkey))
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      if model.removing == passkey.uuid {
        BubbleSpinner()
      } else {
        Button {
          model.rename.begin(passkey.uuid, name: passkey.name)
        } label: {
          Image(systemName: "pencil")
        }
        .accentRow()
        .accessibilityLabel("Rename \u{201C}\(passkey.name)\u{201D}")
        Button(role: .destructive) {
          model.confirmingRemove = passkey
        } label: {
          Image(systemName: "trash")
        }
        .tint(Color.danger)
        .accessibilityLabel("Remove \u{201C}\(passkey.name)\u{201D}")
        .rowConfirmation(
          PasskeysModel.removeTitle, for: passkey, confirming: Bindable(model).confirmingRemove
        ) { passkey in
          Button(PasskeysModel.removeButton, role: .destructive) {
            Task { await model.confirmRemove(passkey) }
          }
        } message: { passkey in
          Text(PasskeysModel.removeMessage(passkey))
        }
      }
    }
    .buttonStyle(.borderless)
    .disabled(model.isBusy || model.rename.editing != nil)
  }
}

#Preview {
  @Previewable @State var model = PasskeysModel(session: AuthenticationPreviewData.session)
  List {
    PasskeysSection(model: model)
  }
  .task { await model.list.load() }
}
