import SwiftUI

/// The frame every record form shares: the server's sentence about a refused item above the
/// fields and the reason a save did not keep below them. In a sheet it has the web dialog's title
/// and *Cancel* and *Create* in teal. Pushed, as a tab's own create and a page's edit are, it is
/// laid out as the dive form is, with its save button fixed under it and any delete at its end.
struct RecordSheetForm<Content: View>: View {
  let title: String
  /// The sheet reopened a refused item or a record: its button saves the change.
  var isReopened = false
  /// The name a pushed form's button creates under, the web's.
  var createLabel = "Create"
  var isPushed = false
  var failure: String?
  var saveError: String?
  var deletion: RecordDeletion?
  /// Returns whether the write was kept, which closes the sheet.
  let save: () -> Bool
  @ViewBuilder let content: Content

  @Environment(\.dismiss) private var dismiss

  var body: some View {
    if isPushed {
      form(showsSaveError: false)
        .pinnedToBottom {
          FormSaveBar(label: isReopened ? Self.saveLabel : createLabel, error: saveError) {
            if save() { dismiss() }
          }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    } else {
      NavigationStack {
        form(showsSaveError: true)
          .navigationTitle(title)
          .navigationBarTitleDisplayMode(.inline)
          .toolbar {
            ToolbarItem(placement: .cancellationAction) {
              Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
              ToolbarConfirmButton(title: isReopened ? Self.saveLabel : "Create") {
                if save() { dismiss() }
              }
            }
          }
      }
    }
  }

  private static var saveLabel: String { "Save changes" }

  private func form(showsSaveError: Bool) -> some View {
    Form {
      if let failure {
        Section {
          Label(failure, systemImage: "exclamationmark.triangle")
            .foregroundStyle(Color.danger)
        }
      }
      content
      if showsSaveError, let saveError {
        Section {
          Text(saveError).foregroundStyle(Color.danger)
        }
      }
      if let deletion {
        DeleteRecordSection(title: deletion.title, message: deletion.message) {
          guard deletion.delete() else { return }
          // The form first: the page under it asked to go first leaves the form's pop unheard,
          // and the diver on the deleted record's page.
          dismiss()
          deletion.onDeleted()
        }
      }
    }
    .background(TapEndsTyping())
  }
}

/// What an edit form's delete says, and does. `delete` returns whether it was queued, which
/// closes the form and then tells the page it was opened from.
struct RecordDeletion {
  let title: String
  let message: String
  let delete: () -> Bool
  let onDeleted: () -> Void
}

#Preview {
  RecordSheetForm(
    title: "New Person", failure: "Name is required.",
    save: { false }, content: { Text("Fields") })
}
