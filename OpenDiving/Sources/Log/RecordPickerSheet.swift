import OpenDivingKit
import SwiftUI

/// One of the form's record pickers: the phone's rows first, searched as the diver types, then
/// the server's matches when it can be asked, and the web's *Add…* row, which opens the
/// record's sheet and picks what it creates.
struct RecordPickerSheet: View {
  let model: DiveFormModel
  let picker: FormPicker
  /// The tank a cylinder is picked for.
  var tank: Int?
  /// A single pick that holds a record offers *None* to clear it.
  var current: RecordRef?
  /// The people picker's create on Return, with the text typed; true when it took it.
  var onSubmitText: ((String) -> Bool)?
  let onPick: (RecordRef?) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var text = ""
  @State private var found: [FormPickerRow] = []
  @State private var adding = false

  var body: some View {
    NavigationStack {
      let rows = model.rows(picker, matching: text, tank: tank)
      List {
        if current != nil {
          Button("None") { pick(nil) }
        }
        ForEach(rows + found) { row in
          Button {
            model.remember(row)
            pick(row.ref)
          } label: {
            PickerRowLabel(row: row, isSelected: row.ref == current)
          }
        }
        if rows.isEmpty && found.isEmpty {
          Text(model.emptySentence(picker, matching: text, tank: tank))
            .foregroundStyle(.secondary)
        }
        Section {
          Button(picker.addLabel, systemImage: "plus") { adding = true }
        }
      }
      .searchable(
        text: $text, placement: .navigationBarDrawer(displayMode: .always),
        prompt: picker.placeholder(holdsSome: false)
      )
      .onSubmit(of: .search) {
        if let onSubmitText, onSubmitText(text) { dismiss() }
      }
      .task(id: text) {
        found = []
        try? await Task.sleep(for: .milliseconds(300))
        guard !Task.isCancelled else { return }
        found = await model.searchServer(picker, matching: text, tank: tank)
      }
      .navigationTitle(picker.placeholder(holdsSome: false))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
      }
      .sheet(isPresented: $adding) {
        picker.addSheet { ref in
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
          Text(row.title).foregroundStyle(.primary)
          if row.isPending { PendingMark() }
        }
        if let subtitle = row.subtitle {
          Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
        }
      }
      Spacer()
      if isSelected {
        Image(systemName: "checkmark").foregroundStyle(.tint)
      }
    }
  }
}

#Preview {
  RecordPickerSheet(
    model: DiveFormModel(session: DivePreviewData.session, mode: .create), picker: .trip
  ) { _ in }
}
