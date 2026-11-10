import OpenDivingKit
import SwiftUI

/// The contact form as a screen of its own, which a contact has in place of a page: a new contact,
/// a contact's edit from its row, or a queued edit the server refused. Its edit also offers the
/// web row's Delete.
struct ContactFormView: View {
  let mode: RecordFormMode<ContactRead>
  /// The contact was deleted from the form, which leaves its row nothing to show.
  var onDeleted: () -> Void = {}

  @Environment(Session.self) private var session

  var body: some View {
    switch mode {
    case .create:
      form(
        RecordSheetModel(
          outbox: OutboxModel(session: session), values: ContactFormValues()))
    case .edit(let contact):
      form(edit(contact, failedItem: nil))
    case .failed(let item, let uuid):
      RecordFormLoader {
        try await session.requireClient().contact(uuid)
      } content: { contact in
        form(edit(contact, failedItem: item))
      }
    }
  }

  private func edit(_ contact: ContactRead, failedItem: UUID?)
    -> RecordSheetModel<ContactFormValues>
  {
    RecordSheetModel(
      outbox: OutboxModel(session: session), editing: .server(contact.uuid),
      read: ContactFormValues(editing: contact), failedItem: failedItem)
  }

  private func form(_ model: RecordSheetModel<ContactFormValues>) -> some View {
    ContactSheetForm(
      model: model, map: MapStyleModel(session: session), isPushed: true, onCreated: { _ in },
      onDeleted: onDeleted)
  }
}

#Preview {
  NavigationStack {
    ContactFormView(mode: .create)
  }
  .environment(Session.stub(transport: StubTransport(routes: [:])))
}
