import OpenDivingKit
import SwiftUI

/// The sheet a record is picked in, whichever form opens it: the rows, searched as the diver types
/// in the bar the system places, *None* where a record is held, and a + that opens the record's own
/// sheet and picks what it creates.
struct PickerSheet<AddSheet: View>: View {
  let title: String
  let rows: (String) -> [FormPickerRow]
  /// What the server adds to the phone's rows, where it can be asked.
  var search: ((String) async -> [FormPickerRow])?
  let emptySentence: (String) -> String
  /// A single pick that holds a record offers *None* to clear it.
  var current: RecordRef?
  /// What Return does with the text typed; true when it took it.
  var onSubmitText: ((String) -> Bool)?
  /// A row chosen, before the sheet closes.
  var onChoose: (FormPickerRow) -> Void = { _ in }
  let addLabel: String
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
        ToolbarItem(placement: .primaryAction) {
          Button(addLabel, systemImage: "plus") { adding = true }
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

/// A picker row: the record's name, what tells it apart, and the mark of one not yet on the
/// server.
struct PickerRowLabel: View {
  let row: FormPickerRow
  var isSelected = false

  var body: some View {
    HStack {
      VStack(alignment: .leading, spacing: 2) {
        HStack(spacing: 6) {
          Text(row.title).foregroundStyle(Color.primary)
          if row.isPending { PendingMark() }
        }
        if let subtitle = row.subtitle {
          Text(subtitle).font(.subheadline).foregroundStyle(Color.secondary)
        }
      }
      Spacer()
      if isSelected {
        Image(systemName: "checkmark").foregroundStyle(Color.accentText)
      }
    }
  }
}

#Preview {
  PickerSheet(
    title: "Select a person...", rows: { _ in [] }, emptySentence: { _ in "No people yet." },
    addLabel: "Add person...", addSheet: { _ in EmptyView() }, onPick: { _ in })
}
