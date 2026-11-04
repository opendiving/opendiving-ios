import OpenDivingKit
import SwiftUI

/// The dive's gear: *Load a gear set…*, which opens the set as a checklist — after the web's
/// confirmation when the dive already has gear — then the items one by one and the picker that
/// adds the next.
struct GearField: View {
  @Bindable var model: DiveFormModel

  @State private var picking = false
  @State private var choosingSet = false
  @State private var chosenSet: GearSetRow?
  @State private var replacing: GearSetRow?

  var body: some View {
    let gear = model.values.gearItems
    Button(model.lookups.gearSets.isEmpty ? "No gear sets yet" : "Load a gear set...") {
      choosingSet = true
    }
    .disabled(model.lookups.gearSets.isEmpty)
    // Waits for the picker to close: a set goes on to a dialog or the checklist's own sheet.
    .sheet(isPresented: $choosingSet, onDismiss: loadChosenSet) {
      GearSetPickerSheet(sets: model.lookups.gearSets) { chosenSet = $0 }
    }
    if let checklist = model.checklist, model.gearSet != nil {
      Button("Checklist: \(checklist.name)", systemImage: "checkmark.circle") {
        model.reopenChecklist()
      }
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
      .sheet(isPresented: $picking) {
        RecordPickerSheet(model: model, picker: .gear) { ref in
          if let ref { model.addGear(ref) }
        }
      }
      .sheet(isPresented: $model.isChecklistOpen) {
        GearChecklistSheet(model: model)
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

  private func loadChosenSet() {
    if let chosenSet { pick(chosenSet) }
    chosenSet = nil
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
