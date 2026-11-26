import OpenDivingKit
import SwiftUI

/// A new API key's page, with the web's fields and defaults. Pushed while the model is creating
/// and gone once the key is made, back to the list, where its secret shows on its row.
struct APIKeyCreateScreen: View {
  @Bindable var model: APIKeysModel
  @FocusState private var nameFocused: Bool

  var body: some View {
    Form {
      Section {
        TextField("Name", text: $model.name, prompt: Text(APIKeysModel.namePlaceholder))
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()
          .submitLabel(.done)
          .focused($nameFocused)
          .onSubmit(create)
      } footer: {
        // At the top, by the button that made it: the permissions run far below the fold.
        VStack(alignment: .leading, spacing: 8) {
          if let error = model.nameError {
            FieldMessage(error)
          }
          if let failure = model.createFailure {
            FieldMessage(failure)
          }
        }
      }
      Section {
        Picker("Expires after", selection: $model.lifetime) {
          ForEach(APIKeyLifetime.allCases, id: \.self) { lifetime in
            Text(APIKeysModel.label(lifetime)).tag(lifetime)
          }
        }
      }
      Section {
        if model.permissions.isAbsent {
          Text(APIKeysModel.permissionsAbsent)
            .foregroundStyle(.secondary)
        } else if model.permissions.value == nil {
          OptionalListStatus(
            list: model.permissions, failed: APIKeysModel.permissionsLoadFailed,
            loading: "Loading permissions…")
        } else {
          PermissionPicker(model: model)
            // A pick shows at once: dozens of toggles fading together read as lag.
            .transaction { transaction in
              transaction.animation = nil
              transaction.disablesAnimations = true
            }
        }
      } footer: {
        if model.permissions.value != nil {
          Text(APIKeysModel.permissionsNote)
        }
      }
    }
    .disabled(model.isSubmitting)
    // Leaving mid-create would close a page the model still holds open.
    .navigationBarBackButtonHidden(model.isSubmitting)
    .navigationTitle(APIKeysModel.createButton)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .confirmationAction) {
        if model.isSubmitting {
          BubbleSpinner()
        } else {
          ToolbarConfirmButton(title: "Create", action: create)
            .disabled(!model.canSubmit)
            .needsServer()
        }
      }
    }
    .task { await model.permissions.load() }
    .onAppear { nameFocused = true }
  }

  private func create() {
    Task { await model.create() }
  }
}

/// The permissions a new key is given, a row per kind of content with a button per action.
private struct PermissionPicker: View {
  let model: APIKeysModel

  var body: some View {
    let groups = PermissionGroup.groups(model.permissions.value ?? [])
    HStack {
      VStack(alignment: .leading, spacing: 2) {
        Text(APIKeysModel.permissionsTitle)
          .font(.headline)
        Text(model.grantedCount)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Spacer()
      Button("Read only") { model.grantReadsOnly() }
        .accentRow()
      Button(model.isAllGranted ? "Deselect all" : "Select all") {
        if model.isAllGranted { model.grantNone() } else { model.grantAll() }
      }
      .brandBorderedButton()
    }
    .buttonStyle(.borderless)
    if let error = model.scopesError {
      FieldMessage(error)
    }
    ForEach(groups) { group in
      VStack(alignment: .leading, spacing: 6) {
        Text(group.label)
        FlowLayout(spacing: 6) {
          ForEach(group.permissions) { permission in
            let granted = model.isGranted(permission.scope)
            Toggle(
              permission.label,
              isOn: Binding(
                get: { granted },
                set: { model.grant(permission.scope, $0) })
            )
            .toggleStyle(.button)
            // An off toggle's fill is already grey; its tint is the only accent left on it.
            .brandBorderedButton(granted ? .accentText : .secondary)
            .font(.subheadline)
            .accessibilityLabel(group.spoken(permission))
          }
        }
      }
    }
  }
}

#Preview {
  @Previewable @State var model = APIKeysModel(session: AuthenticationPreviewData.session)
  NavigationStack {
    APIKeyCreateScreen(model: model)
  }
  .task {
    await model.list.load()
    model.startCreating()
  }
  .environment(AuthenticationPreviewData.session)
}
