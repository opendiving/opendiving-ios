import OpenDivingKit
import SwiftUI

/// The person form as a screen of its own: a new person, a person's page's edit, or a queued edit
/// the server refused.
struct PersonFormView: View {
  let mode: RecordFormMode<PersonRead>
  /// The person was deleted from the form, which leaves the page it was opened from nothing to
  /// show.
  var onDeleted: () -> Void = {}

  @Environment(Session.self) private var session

  var body: some View {
    switch mode {
    case .create:
      form(RecordSheetModel(outbox: OutboxModel(session: session), values: PersonFormValues()))
    case .edit(let person):
      form(edit(person, failedItem: nil), person: person)
    case .failed(let item, let uuid):
      RecordFormLoader {
        try await session.requireClient().person(uuid)
      } content: { person in
        form(edit(person, failedItem: item), person: person)
      }
    }
  }

  private func edit(_ person: PersonRead, failedItem: UUID?) -> RecordSheetModel<PersonFormValues> {
    RecordSheetModel(
      outbox: OutboxModel(session: session), editing: .server(person.uuid),
      read: PersonFormValues(editing: person), failedItem: failedItem)
  }

  private func form(
    _ model: RecordSheetModel<PersonFormValues>, person: PersonRead? = nil
  ) -> some View {
    PersonSheetForm(
      model: model, isPushed: true, person: person, onCreated: { _ in }, onDeleted: onDeleted)
  }
}

#Preview {
  NavigationStack {
    PersonFormView(mode: .create)
  }
  .environment(Session.stub(transport: StubTransport(routes: [:])))
}
