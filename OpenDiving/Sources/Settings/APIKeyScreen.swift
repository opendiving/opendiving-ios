import OpenDivingKit
import SwiftUI

/// One API key: what it is, what it may do, and its revocation at the foot.
struct APIKeyScreen: View {
  let model: APIKeysModel
  let key: APIKeyRead
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    // Read from the list so a refresh that lands while the page is open shows here too.
    let key = model.list.value?.first { $0.uuid == self.key.uuid } ?? self.key
    List {
      Section {
        LabeledContent("Name", value: key.name)
        LabeledContent("Key") {
          Text(key.prefix + "\u{2026}")
            .font(.body.monospaced())
        }
        LabeledContent("Access", value: APIKeysModel.label(key.scope))
        if key.isExpired(at: model.now) {
          BadgeView(APIKeysModel.expired, style: .destructive) { EmptyView() }
        }
      } footer: {
        Text(APIKeysModel.details(key, now: model.now))
      }
      Section {
        if key.scope == .scoped, let scopes = key.scopes {
          ForEach(PermissionGroup.groups(scopes)) { group in
            LabeledContent(group.label, value: group.actions)
          }
        } else {
          Text(APIKeysModel.legacyAccess)
            .foregroundStyle(.secondary)
        }
      } header: {
        if key.scope == .scoped, let scopes = key.scopes {
          Text("Permissions \u{00B7} \(scopes.count)")
        } else {
          Text("Permissions")
        }
      }
      Section {
        // Drawn as DeleteRecordSection draws a form's delete, with a spinner while it runs.
        Button(role: .destructive) {
          model.confirmingRevoke = key
        } label: {
          Text(APIKeysModel.revokeTitle)
            .bold()
            .frame(maxWidth: .infinity)
            .overlay(alignment: .trailing) {
              if model.revoking == key.uuid {
                BubbleSpinner()
              }
            }
        }
        .dangerRow()
        .disabled(model.revoking != nil)
        .needsServer()
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 0, trailing: 16))
        .rowConfirmation(
          APIKeysModel.revokeTitle, for: key, confirming: Bindable(model).confirmingRevoke
        ) { key in
          Button(APIKeysModel.revokeButton, role: .destructive) {
            Task {
              await model.confirmRevoke(key)
              if model.revokeFailure == nil { dismiss() }
            }
          }
        } message: { key in
          Text(APIKeysModel.revokeMessage(key))
        }
      } footer: {
        if let failure = model.revokeFailure {
          FieldMessage(failure)
        }
      }
      .listSectionSpacing(.compact)
    }
    .navigationTitle(key.name)
    .navigationBarTitleDisplayMode(.inline)
  }
}

#Preview {
  @Previewable @State var model = APIKeysModel(session: AuthenticationPreviewData.session)
  NavigationStack {
    if let key = model.list.value?.first {
      APIKeyScreen(model: model, key: key)
    }
  }
  .task { await model.list.load() }
  .environment(AuthenticationPreviewData.session)
}
