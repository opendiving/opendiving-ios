import OpenDivingKit
import SwiftUI

/// *Settings* → *Preferences*: the account's units, saved on change, and its tags.
struct PreferencesScreen: View {
  @Environment(Session.self) private var session

  var body: some View {
    PreferencesList(session: session)
      .navigationTitle("Preferences")
      .followsAccount(session)
  }
}

private struct PreferencesList: View {
  @State private var model: PreferencesModel

  init(session: Session) {
    _model = State(initialValue: PreferencesModel(session: session))
  }

  var body: some View {
    List {
      Section {
        Picker(
          "Measurement system",
          selection: Binding(
            get: { model.units },
            set: { units in Task { await model.setUnits(units) } })
        ) {
          ForEach(UnitSystem.allCases, id: \.self) { system in
            Text(UnitsText.label(system)).tag(system)
          }
        }
        .pickerStyle(.inline)
        .labelsHidden()
        .disabled(model.write.isSaving)
      } header: {
        Text("Units")
      } footer: {
        VStack(alignment: .leading, spacing: 8) {
          if let failure = model.write.failure {
            FieldMessage(failure)
          }
          Text(UnitsText.description)
          Text(UnitsText.entryDescription)
        }
      }
      TagsSection(model: model.tags)
    }
  }
}

/// The tags, each renamed in its row or deleted after a confirmation.
private struct TagsSection: View {
  let model: TagsModel

  var body: some View {
    Section {
      if let tags = model.tags {
        if tags.isEmpty {
          Text("No tags yet. Add one to a dive or a dive site from its form.")
            .foregroundStyle(.secondary)
        }
        ForEach(tags) { tag in
          if model.rename.editing == tag.uuid {
            InlineRenameRow(
              original: tag.name, draft: Bindable(model.rename).draft,
              canSave: model.rename.canSave,
              isSaving: model.rename.isSaving
            ) {
              Task { await model.saveRename() }
            } stop: {
              model.rename.stop()
            }
          } else {
            row(tag)
          }
        }
      } else if let failure = model.loadFailure {
        Text("Your tags could not be loaded. " + failure)
          .foregroundStyle(.secondary)
      } else {
        HStack {
          BubbleSpinner()
          Text("Loading tags…")
        }
        .foregroundStyle(.secondary)
      }
    } header: {
      Text("Tags")
    } footer: {
      VStack(alignment: .leading, spacing: 8) {
        if let failure = model.rename.failure ?? model.deleteFailure {
          FieldMessage(failure)
        }
        Text(
          "The words you file dives and dive sites under. A rename reaches everything carrying"
            + " the tag.")
      }
    }
    .task { await model.load() }
    .task { await model.followRoute() }
    .confirmationDialog(
      "Delete tag",
      isPresented: Binding(
        get: { model.confirmingDelete != nil },
        set: { if !$0 { model.confirmingDelete = nil } }),
      titleVisibility: .visible, presenting: model.confirmingDelete
    ) { tag in
      Button("Delete", role: .destructive) { Task { await model.confirmDelete(tag) } }
    } message: { _ in
      Text(TagsModel.confirmMessage)
    }
  }

  private func row(_ tag: TagRead) -> some View {
    HStack(spacing: 12) {
      Text("\(tag.name) \(Text("· " + TagsModel.usage(tag)).foregroundStyle(.secondary))")
        .frame(maxWidth: .infinity, alignment: .leading)
      if model.deleting == tag.uuid {
        BubbleSpinner()
      } else {
        Button {
          model.rename.begin(tag.uuid, name: tag.name)
        } label: {
          Image(systemName: "pencil")
        }
        .accessibilityLabel("Rename \u{201C}\(tag.name)\u{201D}")
        Button(role: .destructive) {
          model.confirmingDelete = tag
        } label: {
          Image(systemName: "trash")
        }
        .tint(Color.danger)
        .accessibilityLabel("Delete \u{201C}\(tag.name)\u{201D}")
      }
    }
    .buttonStyle(.borderless)
    .disabled(model.isBusy || model.rename.editing != nil)
  }
}

#Preview {
  NavigationStack {
    PreferencesScreen()
  }
  .environment(Session.stub(transport: StubTransport(routes: [:])))
}
