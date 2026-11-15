import OpenDivingKit
import SwiftUI

/// The account's API keys: created from a form in the section, the new key's secret shown once
/// on its row, and each opening a page of its own with its permissions and its revocation.
struct APIKeysSection: View {
  let model: APIKeysModel

  var body: some View {
    if !model.list.isAbsent {
      Section {
        if let lastUpdated = model.list.lastUpdated {
          LastUpdatedLine(date: lastUpdated)
        }
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
        Text(APIKeysModel.description)
      }
    }
  }

  private func row(_ key: APIKeyRead) -> some View {
    NavigationLink {
      APIKeyScreen(model: model, key: key)
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
