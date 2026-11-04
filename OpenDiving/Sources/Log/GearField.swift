import OpenDivingKit
import SwiftUI

/// The dive's gear: *Load a gear set…*, which opens the set as a checklist — after the web's
/// confirmation when the dive already has gear — then the items, each a row of the form that drags
/// to a new place and swipes away, and the picker that adds the next.
struct GearField: View {
  let model: DiveFormModel

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
      PickerSheet(
        title: "Load a gear set...", searchPrompt: "Search gear sets...",
        rows: { LookupsModel.matching(model.lookups.gearSets, $0).map(Self.row) },
        addLabel: nil, addSheet: { _ in EmptyView() },
        onPick: { ref in chosenSet = model.lookups.gearSets.first { $0.ref == ref } })
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
    if let checklist = model.checklist, model.gearSet != nil {
      Button("Checklist: \(checklist.name)", systemImage: "checkmark.circle") {
        model.reopenChecklist()
      }
      .accentRow()
    }
    SortableRows(
      items: model.binding(\.gearItems), identity: { $0 }, title: { model.row($0, .gear).title },
      row: { _, ref in
        let item = model.gearInfo(ref)
        HStack {
          PickerRowLabel(row: model.row(ref, .gear))
          if item?.rented == true { BadgeView("Rented") }
          if item?.isArchived == true { BadgeView("Archived", style: .outline) }
          if gear.count > 1 { DragHandle() }
        }
      })
    Button(FormPicker.gear.placeholder(holdsSome: !gear.isEmpty)) { picking = true }
      .accentRow()
      .sheet(isPresented: $picking) {
        RecordPickerSheet(model: model, picker: .gear) { ref in
          if let ref { model.addGear(ref) }
        }
      }
  }

  private static func row(_ set: GearSetRow) -> FormPickerRow {
    FormPickerRow(ref: set.ref, title: DiveFormModel.setLabel(set))
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
