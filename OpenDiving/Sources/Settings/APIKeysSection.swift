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
        if model.list.value?.isEmpty == true, !model.isCreating {
          Text(APIKeysModel.empty)
            .foregroundStyle(.secondary)
        }
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
      .confirmationDialog(
        APIKeysModel.revokeTitle,
        isPresented: Binding(
          get: { model.confirmingRevoke != nil },
          set: { if !$0 { model.confirmingRevoke = nil } }),
        titleVisibility: .visible, presenting: model.confirmingRevoke
      ) { _ in
        Button(APIKeysModel.revokeButton, role: .destructive) {
          Task { await model.confirmRevoke() }
        }
      } message: { key in
        Text(APIKeysModel.revokeMessage(key))
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
    Picker("Access", selection: $model.scope) {
      ForEach(APIKeyScope.allCases, id: \.self) { scope in
        Text(APIKeysModel.label(scope)).tag(scope)
      }
    }
    .disabled(model.isSubmitting)
    Picker("Expires after", selection: $model.lifetime) {
      ForEach(APIKeyLifetime.allCases, id: \.self) { lifetime in
        Text(APIKeysModel.label(lifetime)).tag(lifetime)
      }
    }
    .disabled(model.isSubmitting)
    if let failure = model.createFailure {
      FieldMessage(failure)
    }
    HStack {
      Button("Cancel") { model.cancelCreating() }
        .disabled(model.isSubmitting)
      Spacer()
      if model.isSubmitting {
        BubbleSpinner()
      }
      Button("Create key") { Task { await model.create() } }
        .buttonStyle(.borderedProminent)
        .disabled(model.isSubmitting)
    }
    .buttonStyle(.borderless)
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
}
