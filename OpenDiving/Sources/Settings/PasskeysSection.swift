import OpenDivingKit
import SwiftUI

/// The passkeys, each renamed in its row or removed after a confirmation, from its context menu
/// or a swipe. Nothing here adds one.
struct PasskeysSection: View {
  let model: PasskeysModel

  var body: some View {
    if model.isShown {
      Section {
        if let lastUpdated = model.list.lastUpdated {
          LastUpdatedLine(date: lastUpdated)
        }
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
      }
    }
    .contextMenu {
      Button("Rename", systemImage: "pencil") { rename(passkey) }
        .actionEnabled(isEnabled)
      Button("Remove", systemImage: "trash", role: .destructive) { remove(passkey) }
        .actionEnabled(isEnabled)
    }
    .swipeActions(edge: .leading) {
      Button("Rename", systemImage: "pencil") { rename(passkey) }
        .tint(.brandTeal)
        .actionEnabled(isEnabled)
    }
    // Not the destructive role, whose swipe takes the row away before the dialog asks.
    .swipeActions(edge: .trailing) {
      Button("Remove", systemImage: "trash") { remove(passkey) }
        .tint(.dangerFill)
        .actionEnabled(isEnabled)
    }
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

  private var isEnabled: Bool { !model.isBusy && model.rename.editing == nil }

  private func rename(_ passkey: PasskeyRead) {
    model.rename.begin(passkey.uuid, name: passkey.name)
  }

  private func remove(_ passkey: PasskeyRead) {
    model.confirmingRemove = passkey
  }
}

extension View {
  /// A row action, off while another is under way or the phone has no route to the server.
  fileprivate func actionEnabled(_ isEnabled: Bool) -> some View {
    disabled(!isEnabled).needsServer()
  }
}

#Preview {
  @Previewable @State var model = PasskeysModel(session: AuthenticationPreviewData.session)
  List {
    PasskeysSection(model: model)
  }
  .task { await model.list.load() }
  .environment(AuthenticationPreviewData.session)
}
