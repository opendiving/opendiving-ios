import SwiftUI

/// The frame every record sheet shares: the web dialog's title, *Cancel* and its create button,
/// the server's sentence about a refused item above the fields, and the reason a save did not
/// keep below them.
struct RecordSheetForm<Content: View>: View {
  let title: String
  let createLabel: String
  /// The sheet reopened a refused item: its button saves the change, as an edit's does.
  var isReopened = false
  var failure: String?
  var saveError: String?
  /// Returns whether the write was kept, which closes the sheet.
  let save: () -> Bool
  @ViewBuilder let content: Content

  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      Form {
        if let failure {
          Section {
            Label(failure, systemImage: "exclamationmark.triangle")
              .foregroundStyle(.red)
          }
        }
        content
        if let saveError {
          Section {
            Text(saveError).foregroundStyle(.red)
          }
        }
      }
      .navigationTitle(title)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button(isReopened ? "Save changes" : createLabel) {
            if save() { dismiss() }
          }
        }
      }
    }
  }
}

#Preview {
  RecordSheetForm(
    title: "New Person", createLabel: "Create person", failure: "Name is required.",
    save: { false }, content: { Text("Fields") })
}
