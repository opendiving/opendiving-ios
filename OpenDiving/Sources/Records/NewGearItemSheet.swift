import OpenDivingKit
import SwiftUI

/// The web's *New Gear* dialog, a cylinder's volume, working pressure and material shown only
/// for a cylinder: queues the item and hands back its ref, or reopens a queued create the
/// server refused (`failedItem`) and queues it again.
struct NewGearItemSheet: View {
  let failedItem: UUID?
  let onCreated: (RecordRef) -> Void
  /// A tank's cylinder picker opens it as a cylinder.
  var type: String?

  @Environment(Session.self) private var session

  init(failedItem: UUID? = nil, onCreated: @escaping (RecordRef) -> Void) {
    self.failedItem = failedItem
    self.onCreated = onCreated
  }

  /// Opens on a type, the way a picker for one kind of gear asks for a new one.
  init(type: String?, onCreated: @escaping (RecordRef) -> Void) {
    self.init(onCreated: onCreated)
    self.type = type
  }

  var body: some View {
    GearItemSheetForm(
      model: RecordSheetModel(
        outbox: OutboxModel(session: session), values: GearItemFormValues(type: type),
        failedItem: failedItem),
      lookups: LookupsModel(session: session), units: session.units, onCreated: onCreated)
  }
}

private struct GearItemSheetForm: View {
  @State var model: RecordSheetModel<GearItemFormValues>
  @State var lookups: LookupsModel
  let units: UnitSystem
  let onCreated: (RecordRef) -> Void

  @State private var invalid: Set<String> = []

  var body: some View {
    RecordSheetForm(
      title: "New Gear", createLabel: "Create gear", isReopened: model.isReopened,
      failure: model.failure, saveError: model.saveError, save: save
    ) {
      Section {
        TextBox(
          label: "Name *", placeholder: "e.g. MK25 EVO", text: $model.values.name,
          message: model.message("name"))
        TextBox(
          label: "Brand", placeholder: "e.g. Scubapro", text: $model.values.brand,
          message: model.message("brand"))
        Picker("Type", selection: $model.values.type) {
          Text("No type").tag(String?.none)
          ForEach(FormVocabulary.gearTypes, id: \.self) { type in
            Text(VocabularyLabels.gearType(type) ?? type).tag(Optional(type))
          }
        }
      }
      if model.values.isCylinder {
        Section {
          HStack(alignment: .bottom) {
            DecimalBox(
              label: "Volume (L)", key: "volume", placeholder: "e.g. 11.1",
              value: $model.values.volume, invalid: $invalid, message: model.message("volume"))
            volumePresets
          }
          MeasuredField(
            label: "Working pressure", key: "working_pressure", measure: .pressure,
            units: units, example: 232, value: $model.values.workingPressure,
            invalid: $invalid, message: model.message("working_pressure"))
          Picker("Material", selection: $model.values.material) {
            Text("Not recorded").tag(String?.none)
            ForEach(FormVocabulary.cylinderMaterials, id: \.self) { material in
              Text(RecordSheetText.cylinderMaterial(material)).tag(Optional(material))
            }
          }
        }
      }
      Section {
        Toggle("Rented, not owned", isOn: $model.values.rented)
        TextBox(
          label: "Notes", placeholder: "Serial number, service dates, sizing...",
          text: $model.values.notes, message: model.message("notes"), multiline: true)
      }
    }
  }

  private var volumePresets: some View {
    Menu {
      ForEach(VolumePresets.groups(for: units, recent: lookups.recentVolumes), id: \.title) {
        group in
        Section(group.title) {
          ForEach(group.presets, id: \.self) { preset in
            Button(preset.label(units)) { model.values.volume = preset.liters }
          }
        }
      }
    } label: {
      Image(systemName: "list.bullet")
        .accessibilityLabel("Common volumes")
    }
    .padding(.bottom, 8)
  }

  /// A cylinder's boxes, once the type is changed away from one, are neither shown nor sent, so
  /// what they last held cannot hold the save back.
  private var blocking: Set<String> {
    model.values.isCylinder ? invalid : invalid.subtracting(["volume", "working_pressure"])
  }

  private func save() -> Bool {
    guard blocking.isEmpty, let ref = model.save() else { return false }
    onCreated(ref)
    return true
  }
}

#Preview {
  NewGearItemSheet(type: "cylinder") { _ in }
    .environment(Session.stub(transport: StubTransport(routes: [:])))
}
