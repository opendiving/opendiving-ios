import OpenDivingKit
import SwiftUI

/// The account's API keys: created on a page of their own, the new key's secret shown once on
/// its row, and each opening a page of its own with its permissions and its revocation.
struct APIKeysSection: View {
  let model: APIKeysModel
  /// The key whose page is open, held by the screen that pushes it.
  @Binding var opened: APIKeyRead?
  /// Its own, not the model's ``APIKeysModel/confirmingRevoke``, which the key's page presents
  /// from while this row sits under it in the stack.
  @State private var confirmingRevoke: APIKeyRead?

  var body: some View {
    if !model.list.isAbsent {
      Section {
        if let lastUpdated = model.list.lastUpdated {
          LastUpdatedLine(date: lastUpdated)
        }
        OptionalListStatus(
          list: model.list, failed: APIKeysModel.loadFailed, loading: "Loading API keys…")
        ForEach(model.list.value ?? []) { key in
          row(key)
          if let secret = model.secret(for: key) {
            NewSecretRow(secret: secret) { model.done() }
          }
        }
        if model.canCreate {
          Button {
            model.startCreating()
          } label: {
            Label(APIKeysModel.createButton, systemImage: "plus")
          }
          .accentRow()
          .needsServer()
        }
      } header: {
        Text("API keys")
      } footer: {
        VStack(alignment: .leading, spacing: 8) {
          if let failure = model.revokeFailure {
            FieldMessage(failure)
          }
          Text(APIKeysModel.description)
        }
      }
    }
  }

  private func row(_ key: APIKeyRead) -> some View {
    NavigationRow {
      opened = key
    } label: {
      VStack(alignment: .leading, spacing: 4) {
        FlowLayout(spacing: 6) {
          Text(key.name)
          Text(key.prefix + "\u{2026}")
            .font(.caption.monospaced())
            .foregroundStyle(.secondary)
          BadgeView(APIKeysModel.label(key.scope), style: .outline) { EmptyView() }
          if key.isExpired(at: model.now) {
            BadgeView(APIKeysModel.expired, style: .destructive) { EmptyView() }
          }
        }
        Text(APIKeysModel.details(key, now: model.now))
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    // No destructive role on the swipe: the list would slide the row out before the dialog asks.
    .swipeActions {
      revokeButton(key, role: nil)
        .tint(.dangerFill)
    }
    .contextMenu {
      revokeButton(key, role: .destructive)
    }
    .rowConfirmation(APIKeysModel.revokeTitle, for: key, confirming: $confirmingRevoke) { key in
      Button(APIKeysModel.revokeButton, role: .destructive) {
        Task { await model.confirmRevoke(key) }
      }
    } message: { key in
      Text(APIKeysModel.revokeMessage(key))
    }
  }

  private func revokeButton(_ key: APIKeyRead, role: ButtonRole?) -> some View {
    Button(APIKeysModel.revokeButton, systemImage: "trash", role: role) {
      confirmingRevoke = key
    }
    .disabled(model.revoking != nil)
    .needsServer()
  }
}

/// A new key's secret, the one time it can be read.
private struct NewSecretRow: View {
  let secret: String
  let done: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      CopyField(
        value: secret, label: APIKeysModel.secretLabel, copied: APIKeysModel.secretCopied,
        monospaced: true)
      Text(APIKeysModel.secretNote)
        .font(.footnote)
        .foregroundStyle(.secondary)
      HStack {
        Spacer()
        Button("Done", action: done)
          .brandBorderedButton()
      }
    }
    .buttonStyle(.borderless)
  }
}

#Preview {
  @Previewable @State var model = APIKeysModel(session: AuthenticationPreviewData.session)
  List {
    APIKeysSection(model: model, opened: .constant(nil))
  }
  .task { await model.list.load() }
  .environment(AuthenticationPreviewData.session)
}
