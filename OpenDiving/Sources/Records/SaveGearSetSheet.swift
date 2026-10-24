import OpenDivingKit
import SwiftUI

/// The web's *Save as Set* dialog over a dive's gear and weight: a new set, or an existing one
/// replaced whole. Queues the create or the update and hands back the set's ref, or reopens a
/// queued save the server refused (`failedItem`) and queues it again.
struct SaveGearSetSheet: View {
  let items: [RecordRef]
  let weight: Double?
  let failedItem: UUID?
  let onSaved: (RecordRef) -> Void

  @Environment(Session.self) private var session

  init(
    items: [RecordRef], weight: Double?, failedItem: UUID? = nil,
    onSaved: @escaping (RecordRef) -> Void
  ) {
    self.items = items
    self.weight = weight
    self.failedItem = failedItem
    self.onSaved = onSaved
  }

  var body: some View {
    GearSetSheetForm(
      model: RecordSheetModel(
        outbox: OutboxModel(session: session),
        values: GearSetSaveValues(form: GearSetFormValues(weight: weight, items: items)),
        failedItem: failedItem),
      lookups: LookupsModel(session: session), units: RecordEntryUnits(session: session),
      onSaved: onSaved)
  }
}

private struct GearSetSheetForm: View {
  @State var model: RecordSheetModel<GearSetSaveValues>
  @State var lookups: LookupsModel
  @State var units: RecordEntryUnits
  let onSaved: (RecordRef) -> Void

  @State private var invalid: Set<String> = []
  @State private var adding = false

  var body: some View {
    RecordSheetForm(
      title: "Save as Set", createLabel: "Create set", isReopened: model.isReopened,
      failure: model.failure, saveError: model.saveError, save: save
    ) {
      Section {
        Text(
          "Save the gear from this dive as a set you can reuse later. The dive itself is not linked to the set."
        )
        .font(.footnote)
        .foregroundStyle(.secondary)
        // A reopened save keeps the write it was: a create cannot become an update under its key.
        if !model.isReopened {
          Picker("Save to", selection: target) {
            Text("Create a new set").tag(RecordRef?.none)
            ForEach(lookups.gearSets, id: \.ref) { set in
              Text(set.name).tag(Optional(set.ref))
            }
          }
        }
        if model.values.target != nil {
          Text("This replaces everything currently in that set.")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        TextBox(
          label: "Set name *", placeholder: "e.g. Sidemount, Warm water rec",
          text: $model.values.form.name, message: model.message("name"))
      }
      Section("Gear") {
        ForEach(model.values.form.items, id: \.self) { ref in
          HStack {
            Text(name(ref))
            PendingMark(ref: ref)
          }
        }
        .onDelete { model.values.form.items.remove(atOffsets: $0) }
        .onMove { model.values.form.items.move(fromOffsets: $0, toOffset: $1) }
        NavigationLink(model.values.form.items.isEmpty ? "Select gear..." : "Add more gear...") {
          RecordPickerList(
            title: "Gear", rows: offered, selection: pick, addLabel: "Add gear...",
            add: { adding = true })
        }
      }
      Section {
        MeasuredField(
          label: "Weight", key: "weight", measure: .weight, units: units.units(.weight),
          example: 6, value: $model.values.form.weight, invalid: $invalid,
          message: model.message("weight"), onToggle: { units.toggle(.weight) })
        Text("Optional. Loading this set into a dive fills in this weight.")
          .font(.footnote)
          .foregroundStyle(.secondary)
      }
    }
    .sheet(isPresented: $adding) {
      NewGearItemSheet { ref in add(ref) }
    }
  }

  /// Picking an existing set takes its name, which the diver may still change.
  private var target: Binding<RecordRef?> {
    Binding(
      get: { model.values.target },
      set: { ref in
        model.values.target = ref
        model.values.form.name =
          ref.flatMap { ref in
            lookups.gearSets.first { $0.ref == ref }?.name
          } ?? ""
      })
  }

  private var offered: [GearItemLookupItem] {
    lookups.gearItems.filter { !model.values.form.items.contains($0.ref) }
  }

  private var pick: Binding<RecordRef?> {
    Binding(get: { nil }, set: { ref in ref.map(add) })
  }

  private func add(_ ref: RecordRef) {
    if !model.values.form.items.contains(ref) { model.values.form.items.append(ref) }
  }

  private func name(_ ref: RecordRef) -> String {
    lookups.gearItems.first { $0.ref == ref }?.name ?? "New gear"
  }

  private func save() -> Bool {
    guard invalid.isEmpty, let ref = model.save() else { return false }
    onSaved(ref)
    return true
  }
}

#Preview {
  SaveGearSetSheet(items: [], weight: 6) { _ in }
    .environment(Session.stub(transport: StubTransport(routes: [:])))
}
