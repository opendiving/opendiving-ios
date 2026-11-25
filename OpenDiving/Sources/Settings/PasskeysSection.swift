import OpenDivingKit
import SwiftUI

/// The passkeys, each renamed in its row or removed after a confirmation, from its context menu
/// or a swipe. Nothing here adds one.
struct PasskeysSection: View {
  let model: PasskeysModel
  @Environment(Session.self) private var session

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
    // The list's own insets, which the row takes over.
    .padding(.horizontal, 16)
    .padding(.vertical, 15)
    // A swipe slides the row on the cell's own fill.
    .background(Color(.secondarySystemGroupedBackground))
    .contextMenu {
      Button("Rename", systemImage: "pencil") { rename(passkey) }
        .actionEnabled(isEnabled)
      Button("Remove", systemImage: "trash", role: .destructive) { remove(passkey) }
        .actionEnabled(isEnabled)
    }
    // The gear service list's swipe rather than the list's own, which draws its buttons apart
    // from the row.
    .rowSwipeActions(
      leading: canAct
        ? [
          RowSwipeAction(title: "Rename", image: Image(systemName: "pencil"), fill: .brandTeal) {
            rename(passkey)
          }
        ] : [],
      trailing: canAct
        ? [
          RowSwipeAction(title: "Remove", image: Image(systemName: "trash"), fill: .dangerFill) {
            remove(passkey)
          }
        ] : []
    )
    .rowConfirmation(
      PasskeysModel.removeTitle, for: passkey, confirming: Bindable(model).confirmingRemove
    ) { passkey in
      Button(PasskeysModel.removeButton, role: .destructive) {
        Task { await model.confirmRemove(passkey) }
      }
    } message: { passkey in
      Text(PasskeysModel.removeMessage(passkey))
    }
    // The row draws its own insets, so its fill reaches the cell's edges.
    .listRowInsets(EdgeInsets())
  }

  private var isEnabled: Bool { !model.isBusy && model.rename.editing == nil }

  /// A swipe, which has no disabled look, is offered only while its actions could run.
  private var canAct: Bool { isEnabled && session.hasRoute }

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
