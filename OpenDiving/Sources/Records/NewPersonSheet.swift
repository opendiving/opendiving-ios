import OpenDivingKit
import SwiftUI

/// The web's *New Person* dialog: queues the person and hands back their ref, or reopens a
/// queued create the server refused (`failedItem`) and queues it again.
struct NewPersonSheet: View {
  let failedItem: UUID?
  let onCreated: (RecordRef) -> Void

  @Environment(Session.self) private var session

  init(failedItem: UUID? = nil, onCreated: @escaping (RecordRef) -> Void) {
    self.failedItem = failedItem
    self.onCreated = onCreated
  }

  var body: some View {
    PersonSheetForm(
      model: RecordSheetModel(
        outbox: OutboxModel(session: session), values: PersonFormValues(),
        failedItem: failedItem),
      onCreated: onCreated)
  }
}

/// The person form, in the web's dialog's sheet or pushed as a screen of its own. Editing a person
/// connected to an account, it is headed by the account's picture and `@username`, which the form
/// does not change.
struct PersonSheetForm: View {
  @State var model: RecordSheetModel<PersonFormValues>
  var isPushed = false
  /// The person being edited, as last read.
  var person: PersonRead?
  let onCreated: (RecordRef) -> Void
  var onDeleted: () -> Void = {}

  var body: some View {
    RecordSheetForm(
      title: model.isEditing ? "Edit Person" : "New Person", isReopened: model.isReopened,
      createLabel: "Create person", isPushed: isPushed, failure: model.failure,
      saveError: model.saveError, deletion: deletion, save: save
    ) {
      if let person, let username = person.username, !username.isEmpty {
        Section {
          ConnectedAccountHead(picture: PersonPageContent.picture(person), username: username)
        }
      }
      Section {
        TextBox(
          label: "Name *", placeholder: "e.g. Alex M.", text: $model.values.name,
          message: model.message("name"), contentType: .name)
        TextBox(
          label: "Email", text: $model.values.email, message: model.message("email"),
          keyboard: .emailAddress, verbatim: true)
        TextBox(
          label: "Phone", text: $model.values.phone, message: model.message("phone"),
          keyboard: .phonePad)
        NotesField(
          placeholder: "How you met, what they dive, anything worth remembering...",
          text: $model.values.notes,
          error: model.message("notes"))
      }
    }
  }

  private var deletion: RecordDeletion? {
    guard model.canDelete else { return nil }
    return RecordDeletion(
      title: "Delete person", message: RecordDeletionText.person, delete: model.delete,
      onDeleted: onDeleted)
  }

  private func save() -> Bool {
    guard let ref = model.save() else { return false }
    onCreated(ref)
    return true
  }
}

#Preview {
  NewPersonSheet { _ in }
    .environment(Session.stub(transport: StubTransport(routes: [:])))
}
