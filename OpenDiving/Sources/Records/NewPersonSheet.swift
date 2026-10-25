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

private struct PersonSheetForm: View {
  @State var model: RecordSheetModel<PersonFormValues>
  let onCreated: (RecordRef) -> Void

  var body: some View {
    RecordSheetForm(
      title: "New Person", createLabel: "Create person", isReopened: model.isReopened,
      failure: model.failure, saveError: model.saveError, save: save
    ) {
      Section {
        TextBox(
          label: "Name *", placeholder: "e.g. Alex M.", text: $model.values.name,
          message: model.message("name"), contentType: .name)
        VStack(alignment: .leading, spacing: 6) {
          TextBox(
            label: "Username", placeholder: "e.g. alexm", text: $model.values.username,
            message: model.message("username"), verbatim: true)
          Text(
            "Their username on this copy of OpenDiving, if they have an account. You will see its current username and nothing else of theirs, and they are not told."
          )
          .font(.footnote)
          .foregroundStyle(.secondary)
        }
        TextBox(
          label: "Email", text: $model.values.email, message: model.message("email"),
          keyboard: .emailAddress, verbatim: true)
        TextBox(
          label: "Phone", text: $model.values.phone, message: model.message("phone"),
          keyboard: .phonePad)
        TextBox(
          label: "Notes",
          placeholder: "How you met, what they dive, anything worth remembering...",
          text: $model.values.notes, message: model.message("notes"), multiline: true)
      }
    }
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
