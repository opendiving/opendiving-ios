import OpenDivingKit
import SwiftUI

/// The sheet a record is picked in, whichever form opens it: the rows, searched as the diver types
/// in the bar the system places, *None* where a record is held, and where one can be made a + that
/// opens the record's own sheet and picks what it creates.
struct PickerSheet<AddSheet: View>: View {
  let title: String
  let rows: (String) -> [FormPickerRow]
  /// What the server adds to the phone's rows, where it can be asked.
  var search: ((String) async -> [FormPickerRow])?
  var emptySentence: (String) -> String = {
    $0.isEmpty ? "Nothing here yet." : "Nothing found."
  }
  /// A single pick that holds a record offers *None* to clear it.
  var current: RecordRef?
  /// What Return does with the text typed; true when it took it.
  var onSubmitText: ((String) -> Bool)?
  /// A row chosen, before the sheet closes.
  var onChoose: (FormPickerRow) -> Void = { _ in }
  /// Nil where a record of the kind is not made here.
  let addLabel: String?
  @ViewBuilder let addSheet: (@escaping (RecordRef) -> Void) -> AddSheet
  let onPick: (RecordRef?) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var text = ""
  @State private var found: [FormPickerRow] = []
  @State private var adding = false

  var body: some View {
    NavigationStack {
      let shown = rows(text)
      List {
        if current != nil {
          Button("None") { pick(nil) }
            .foregroundStyle(Color.primary)
        }
        ForEach(shown + found) { row in
          Button {
            onChoose(row)
            pick(row.ref)
          } label: {
            PickerRowLabel(row: row, isSelected: row.ref == current)
          }
        }
        if shown.isEmpty && found.isEmpty {
          Text(emptySentence(text))
            .foregroundStyle(.secondary)
        }
      }
      .pickerListSpacing()
      .searchable(text: $text, prompt: title)
      .onSubmit(of: .search) {
        if let onSubmitText, onSubmitText(text) { dismiss() }
      }
      .task(id: text) {
        guard let search else { return }
        found = []
        try? await Task.sleep(for: .milliseconds(300))
        guard !Task.isCancelled else { return }
        found = await search(text)
      }
      .navigationTitle(title)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        if let addLabel {
          ToolbarItem(placement: .primaryAction) {
            Button(addLabel, systemImage: "plus") { adding = true }
          }
        }
      }
      .sheet(isPresented: $adding) {
        addSheet { ref in
          adding = false
          pick(ref)
        }
      }
    }
  }

  private func pick(_ ref: RecordRef?) {
    onPick(ref)
    dismiss()
  }
}

#Preview {
  PickerSheet(
    title: "Select a person...", rows: { _ in [] }, emptySentence: { _ in "No people yet." },
    addLabel: "Add person...", addSheet: { _ in EmptyView() }, onPick: { _ in })
}
