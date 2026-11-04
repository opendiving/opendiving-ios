import OpenDivingKit
import SwiftUI

/// The dive's gear: *Load a gear set…*, which opens the set as a checklist — after the web's
/// confirmation when the dive already has gear — then the items, each a row of the form that drags
/// to a new place and swipes away, and the picker that adds the next.
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
    .accentRow()
    .disabled(model.lookups.gearSets.isEmpty)
    // Waits for the picker to close: a set goes on to a dialog or the checklist's own sheet.
    .sheet(isPresented: $choosingSet, onDismiss: loadChosenSet) {
      GearSetPickerSheet(sets: model.lookups.gearSets) { chosenSet = $0 }
    }
    if let checklist = model.checklist, model.gearSet != nil {
      Button("Checklist: \(checklist.name)", systemImage: "checkmark.circle") {
        model.reopenChecklist()
      }
      .accentRow()
    }
    ForEach(Array(gear.enumerated()), id: \.element) { index, ref in
      let item = model.gearInfo(ref)
      let row = model.row(ref, .gear)
      HStack {
        PickerRowLabel(row: row)
        if item?.rented == true { BadgeView("Rented") }
        if item?.isArchived == true { BadgeView("Archived", style: .outline) }
        if gear.count > 1 { DragHandle() }
      }
      .accessibilityActions {
        if index > 0 {
          Button("Move \(row.title) up") { model.change { $0.gearItems.swapAt(index, index - 1) } }
        }
        if index < gear.count - 1 {
          Button("Move \(row.title) down") {
            model.change { $0.gearItems.swapAt(index, index + 1) }
          }
        }
      }
      .swipeToDelete { model.removeGear(ref) }
    }
    .onMove { from, to in model.change { $0.gearItems.move(fromOffsets: from, toOffset: to) } }
    Button(FormPicker.gear.placeholder(holdsSome: !gear.isEmpty)) { picking = true }
      .accentRow()
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
