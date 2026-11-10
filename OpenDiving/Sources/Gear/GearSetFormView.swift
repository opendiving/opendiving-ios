import OpenDivingKit
import SwiftUI

/// The gear set form as a screen of its own: a new set, a copy of `duplicateOf`, a set's edit from
/// its row, or a queued edit the server refused. A set has no page, so its edit also offers the
/// web row menu's Duplicate and Delete.
struct GearSetFormView: View {
  let mode: RecordFormMode<GearSetRead>
  /// With `.create`: the set the new one starts as a copy of.
  var duplicateOf: GearSetRead?
  /// The set was deleted from the form, which leaves its row nothing to show.
  var onDeleted: () -> Void = {}

  @Environment(Session.self) private var session

  var body: some View {
    switch mode {
    case .create:
      form(
        RecordSheetModel(
          outbox: OutboxModel(session: session),
          values: duplicateOf.map(GearSetFormValues.init(duplicating:)) ?? GearSetFormValues()),
        set: duplicateOf)
    case .edit(let set):
      form(edit(set, failedItem: nil), set: set)
    case .failed(let item, let uuid):
      RecordFormLoader {
        try await session.requireClient().gearSet(uuid)
      } content: { set in
        form(edit(set, failedItem: item), set: set)
      }
    }
  }

  private func edit(_ set: GearSetRead, failedItem: UUID?) -> RecordSheetModel<GearSetFormValues> {
    RecordSheetModel(
      outbox: OutboxModel(session: session), editing: .server(set.uuid),
      read: GearSetFormValues(editing: set), failedItem: failedItem)
  }

  private func form(_ model: RecordSheetModel<GearSetFormValues>, set: GearSetRead?) -> some View {
    GearSetForm(
      model: model, lookups: LookupsModel(session: session),
      units: RecordEntryUnits(session: session), set: set, onDeleted: onDeleted)
  }
}

private struct GearSetForm: View {
  @State var model: RecordSheetModel<GearSetFormValues>
  @State var lookups: LookupsModel
  @State var units: RecordEntryUnits
  /// The set read: the one edited, or the one a copy starts from.
  let set: GearSetRead?
  let onDeleted: () -> Void

  @State private var invalid: Set<String> = []

  var body: some View {
    RecordSheetForm(
      title: model.isEditing ? "Edit Gear Set" : "New Gear Set", isReopened: model.isReopened,
      createLabel: "Create set", isPushed: true, failure: model.failure,
      saveError: model.saveError, deletion: deletion, save: save
    ) {
      Section {
        TextBox(
          label: "Set name *", placeholder: "e.g. Sidemount, Warm water rec",
          text: $model.values.name, message: model.message("name"))
      }
      GearSetItemsSection(
        items: $model.values.items, lookups: lookups, known: set?.gearItems ?? [])
      Section {
        RecordMeasuredField(
          label: "Weight", key: "weight", measure: .weight, units: units.units(.weight),
          example: 6, value: $model.values.weight, invalid: $invalid,
          message: model.message("weight"), onToggle: { units.toggle(.weight) })
        Text("Optional. Loading this set into a dive fills in this weight.")
          .font(.footnote)
          .foregroundStyle(.secondary)
      }
    }
    .toolbar {
      if model.canDelete, let set {
        ToolbarItem(placement: .topBarTrailing) {
          NavigationLink {
            GearSetFormView(mode: .create, duplicateOf: set)
          } label: {
            Label("Duplicate", systemImage: "plus.square.on.square")
          }
        }
      }
    }
  }

  private var deletion: RecordDeletion? {
    guard model.canDelete else { return nil }
    return RecordDeletion(
      title: "Delete gear set", message: RecordDeletionText.gearSet, delete: model.delete,
      onDeleted: onDeleted)
  }

  private func save() -> Bool {
    invalid.isEmpty && model.save() != nil
  }
}

#Preview {
  NavigationStack {
    GearSetFormView(mode: .create)
  }
  .environment(Session.stub(transport: StubTransport(routes: [:])))
}
