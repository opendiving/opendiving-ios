import OpenDivingKit
import SwiftUI

/// A gear set form's *Gear*: the set's items in order, dragged to reorder, and the picker that
/// adds more, with *Add gear...* for an item the account does not have yet.
struct GearSetItemsSection: View {
  @Binding var items: [RecordRef]
  let lookups: LookupsModel
  /// The set's own items as it was read, which name an archived one the picker never offers.
  var known: [GearItemInfo] = []

  @State private var picking = false

  var body: some View {
    Section("Gear") {
      SortableRows(
        items: $items, identity: { $0 }, title: { row($0).title },
        row: { _, ref in
          HStack {
            PickerRowLabel(row: row(ref))
            if items.count > 1 { DragHandle() }
          }
        })
      Button(items.isEmpty ? "Select gear..." : "Add more gear...") {
        picking = true
      }
      .accentRow()
      .sheet(isPresented: $picking) {
        PickerSheet(
          title: "Select gear...", searchPrompt: FormPicker.gear.searchPrompt,
          rows: { LookupsModel.matching(offered, $0).map(FormPickerRow.init) },
          addLabel: "Add gear...", addSheet: { NewGearItemSheet(onCreated: $0) },
          onPick: { ref in ref.map(add) })
      }
    }
  }

  private var offered: [GearItemLookupItem] {
    lookups.gearItems.filter { !items.contains($0.ref) }
  }

  private func add(_ ref: RecordRef) {
    if !items.contains(ref) { items.append(ref) }
  }

  private func row(_ ref: RecordRef) -> FormPickerRow {
    if let item = lookups.gearItems.first(where: { $0.ref == ref }) {
      return FormPickerRow(item)
    }
    if let item = known.first(where: { $0.ref == ref }) {
      return FormPickerRow(
        ref: ref, title: DiveDetailText.gearItemLabel(name: item.name, brand: item.brand))
    }
    return FormPickerRow(ref: ref, title: "New gear")
  }
}

#Preview {
  @Previewable @State var items: [RecordRef] = []
  Form {
    GearSetItemsSection(
      items: $items,
      lookups: LookupsModel(session: Session.stub(transport: StubTransport(routes: [:]))))
  }
  .environment(Session.stub(transport: StubTransport(routes: [:])))
}
