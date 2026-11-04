import SwiftUI

/// The frame every record sheet shares: the web dialog's title, *Cancel* and *Create* in teal,
/// the server's sentence about a refused item above the fields, and the reason a save did not
/// keep below them.
struct RecordSheetForm<Content: View>: View {
  let title: String
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
              .foregroundStyle(Color.danger)
          }
        }
        content
        if let saveError {
          Section {
            Text(saveError).foregroundStyle(Color.danger)
          }
        }
      }
      .background(TapEndsTyping())
      .navigationTitle(title)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          ToolbarConfirmButton(title: isReopened ? "Save changes" : "Create") {
            if save() { dismiss() }
          }
        }
      }
    }
  }
}

#Preview {
  RecordSheetForm(
    title: "New Person", failure: "Name is required.",
    save: { false }, content: { Text("Fields") })
}
