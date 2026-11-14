import OpenDivingKit
import SwiftUI

/// The account's API keys: created from a form in the section, the new key's secret shown once
/// on its row, and each revoked after a confirmation.
struct APIKeysSection: View {
  let model: APIKeysModel

  var body: some View {
    if !model.list.isAbsent {
      Section {
        if model.isCreating {
          APIKeyForm(model: model)
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
    HStack(spacing: 12) {
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
        if key.scope == .scoped, let scopes = key.scopes {
          KeyPermissions(scopes: scopes)
        } else {
          Text(APIKeysModel.legacyAccess)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      if model.revoking == key.uuid {
        BubbleSpinner()
      } else {
        Button(role: .destructive) {
          model.confirmingRevoke = key
        } label: {
          Image(systemName: "trash")
        }
        .tint(Color.danger)
        .accessibilityLabel("Revoke \u{201C}\(key.name)\u{201D}")
        .buttonStyle(.borderless)
        .disabled(model.revoking != nil)
        .needsServer()
        .rowConfirmation(
          APIKeysModel.revokeTitle, for: key, confirming: Bindable(model).confirmingRevoke
        ) { key in
          Button(APIKeysModel.revokeButton, role: .destructive) {
            Task { await model.confirmRevoke(key) }
          }
        } message: { key in
          Text(APIKeysModel.revokeMessage(key))
        }
      }
    }
  }
}

/// The form a new key is made from, with the web's fields and defaults.
private struct APIKeyForm: View {
  @Bindable var model: APIKeysModel

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      TextField("Name", text: $model.name, prompt: Text(APIKeysModel.namePlaceholder))
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .submitLabel(.done)
        .onSubmit { Task { await model.create() } }
      if let error = model.nameError {
        FieldMessage(error)
      }
    }
    .disabled(model.isSubmitting)
    Picker("Expires after", selection: $model.lifetime) {
      ForEach(APIKeyLifetime.allCases, id: \.self) { lifetime in
        Text(APIKeysModel.label(lifetime)).tag(lifetime)
      }
    }
    .disabled(model.isSubmitting)
    if model.permissions.isAbsent {
      Text(APIKeysModel.permissionsAbsent)
        .foregroundStyle(.secondary)
    } else if model.permissions.value == nil {
      OptionalListStatus(
        list: model.permissions, failed: APIKeysModel.permissionsLoadFailed,
        loading: "Loading permissions…")
    } else {
      PermissionPicker(model: model)
    }
    if let error = model.scopesError {
      FieldMessage(error)
    }
    if let failure = model.createFailure {
      FieldMessage(failure)
    }
    HStack {
      Button("Cancel") { model.cancelCreating() }
        .accentRow()
        .disabled(model.isSubmitting)
      Spacer()
      if model.isSubmitting {
        BubbleSpinner()
      }
      Button("Create key") { Task { await model.create() } }
        .buttonStyle(.borderedProminent)
        .disabled(!model.canSubmit)
        .needsServer()
    }
    .buttonStyle(.borderless)
    .task { await model.permissions.load() }
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
      Button("Select all") { model.grantAll() }
        .buttonStyle(.bordered)
    }
    .buttonStyle(.borderless)
    .disabled(model.isSubmitting)
    ForEach(groups) { group in
      VStack(alignment: .leading, spacing: 6) {
        Text(group.label)
        FlowLayout(spacing: 6) {
          ForEach(group.permissions) { permission in
            Toggle(
              permission.label,
              isOn: Binding(
                get: { model.isGranted(permission.scope) },
                set: { model.grant(permission.scope, $0) })
            )
            .toggleStyle(.button)
            .buttonStyle(.bordered)
            .font(.subheadline)
            .accessibilityLabel(group.spoken(permission))
          }
        }
      }
      .disabled(model.isSubmitting)
    }
    Text(APIKeysModel.permissionsNote)
      .font(.footnote)
      .foregroundStyle(.secondary)
  }
}

/// What a scoped key may do, folded away until asked for.
private struct KeyPermissions: View {
  let scopes: [String]

  var body: some View {
    DisclosureGroup {
      VStack(alignment: .leading, spacing: 6) {
        ForEach(PermissionGroup.groups(scopes)) { group in
          LabeledContent(group.label, value: group.actions)
            .font(.caption)
        }
      }
      .padding(.top, 4)
    } label: {
      Text("Permissions \u{00B7} \(scopes.count)")
        .font(.caption)
    }
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
          .buttonStyle(.bordered)
      }
    }
    .buttonStyle(.borderless)
  }
}

#Preview {
  @Previewable @State var model = APIKeysModel(session: AuthenticationPreviewData.session)
  List {
    APIKeysSection(model: model)
  }
  .task { await model.list.load() }
  .environment(AuthenticationPreviewData.session)
}
