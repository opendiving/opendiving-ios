import OpenDivingKit
import SwiftUI

/// The dive's gear: *Load a gear set…*, which opens the set as a checklist — after the web's
/// confirmation when the dive already has gear — and *Save as set*, then the items one by one.
struct GearField: View {
  @Bindable var model: DiveFormModel

  @State private var picking = false
  @State private var replacing: GearSetRow?
  @State private var saving = false

  var body: some View {
    let gear = model.values.gearItems
    VStack(alignment: .leading, spacing: 8) {
      FieldLabel(DiveFormField.gearItems.label)
      HStack {
        Menu {
          ForEach(model.lookups.gearSets, id: \.ref) { set in
            Button(DiveFormModel.setLabel(set)) { pick(set) }
          }
        } label: {
          Label(
            model.lookups.gearSets.isEmpty ? "No gear sets yet" : "Load a gear set...",
            systemImage: "checklist")
        }
        .disabled(model.lookups.gearSets.isEmpty)
        Spacer()
        Button("Save as set", systemImage: "bookmark") { saving = true }
          .disabled(gear.isEmpty)
      }
      .buttonStyle(.borderless)
      if let checklist = model.checklist, model.gearSet != nil {
        Button("Checklist: \(checklist.name)", systemImage: "checkmark.circle") {
          model.reopenChecklist()
        }
        .buttonStyle(.borderless)
      }
      ForEach(gear, id: \.self) { ref in
        let item = model.gearInfo(ref)
        HStack {
          PickerRowLabel(row: model.row(ref, .gear))
          if item?.rented == true { BadgeView("Rented") }
          if item?.isArchived == true { BadgeView("Archived", style: .outline) }
          Button {
            model.removeGear(ref)
          } label: {
            Image(systemName: "xmark")
          }
          .buttonStyle(.borderless)
          .accessibilityLabel("Remove \(model.row(ref, .gear).title)")
        }
      }
      Button(FormPicker.gear.placeholder(holdsSome: !gear.isEmpty)) { picking = true }
        .buttonStyle(.borderless)
    }
    .sheet(isPresented: $picking) {
      RecordPickerSheet(model: model, picker: .gear) { ref in
        if let ref { model.addGear(ref) }
      }
    }
    .sheet(isPresented: $model.isChecklistOpen) {
      GearChecklistSheet(model: model)
    }
    .sheet(isPresented: $saving) {
      SaveGearSetSheet(items: model.values.gearItems, weight: model.values.weight) { _ in }
    }
    .confirmationDialog(
      "Replace this dive's gear?",
      isPresented: Binding(get: { replacing != nil }, set: { if !$0 { replacing = nil } }),
      titleVisibility: .visible, presenting: replacing
    ) { set in
      Button("Replace") {
        model.loadSet(set)
        replacing = nil
      }
      Button("Cancel", role: .cancel) { replacing = nil }
    } message: { set in
      Text(model.replaceSentence(set))
    }
  }

  /// The web asks once, at the pick, before a set replaces gear the dive holds.
  private func pick(_ set: GearSetRow) {
    if model.loadingSetReplacesGear {
      replacing = set
    } else {
      model.loadSet(set)
    }
  }
}

#Preview {
  Form {
    GearField(model: DiveFormModel(session: DivePreviewData.session, mode: .create))
  }
}
