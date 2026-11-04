import OpenDivingKit
import SwiftUI

/// One record picked from what the phone holds — a dive centre, an instructor, a place to stay
/// — as the web's comboboxes pick one, in the sheet every form's pickers share.
struct RecordPicker<Row: LookupRow, NewSheet: View>: View {
  let label: String
  let placeholder: String
  let searchPrompt: String
  let addLabel: String
  let rows: [Row]
  @Binding var selection: RecordRef?
  /// The sheet that makes a new record, handed what to do with its ref.
  let newSheet: (@escaping (RecordRef) -> Void) -> NewSheet

  @State private var picking = false

  var body: some View {
    PickerFieldRow(title: label, row: selected, prompt: placeholder) { picking = true }
      .sheet(isPresented: $picking) {
        PickerSheet(
          title: placeholder, searchPrompt: searchPrompt,
          rows: { LookupsModel.matching(rows, $0).map(FormPickerRow.init) }, current: selection,
          addLabel: addLabel, addSheet: newSheet, onPick: { selection = $0 })
      }
  }

  private var selected: FormPickerRow? {
    selection.map { ref in
      rows.first { $0.ref == ref }.map(FormPickerRow.init)
        ?? FormPickerRow(ref: ref, title: "New record")
    }
  }
}

#Preview {
  @Previewable @State var selection: RecordRef?
  NavigationStack {
    Form {
      RecordPicker(
        label: "Dive center", placeholder: "Select a dive center...",
        searchPrompt: "Search dive centers...", addLabel: "Add dive center...",
        rows: [PersonLookupItem](), selection: $selection
      ) { _ in Text("New") }
    }
  }
}
