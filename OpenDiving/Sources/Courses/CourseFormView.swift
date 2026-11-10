import OpenDivingKit
import SwiftUI

/// The course form as a screen of its own: a new course, a course's page's edit, or a queued edit
/// the server refused.
struct CourseFormView: View {
  let mode: RecordFormMode<CourseRead>
  /// The course was deleted from the form, which leaves its page nothing to show.
  var onDeleted: () -> Void = {}

  @Environment(Session.self) private var session

  var body: some View {
    switch mode {
    case .create:
      form(RecordSheetModel(outbox: OutboxModel(session: session), values: CourseFormValues()))
    case .edit(let course):
      form(edit(course, failedItem: nil))
    case .failed(let item, let uuid):
      RecordFormLoader {
        try await session.requireClient().course(uuid)
      } content: { course in
        form(edit(course, failedItem: item))
      }
    }
  }

  private func edit(_ course: CourseRead, failedItem: UUID?) -> RecordSheetModel<CourseFormValues> {
    RecordSheetModel(
      outbox: OutboxModel(session: session), editing: .server(course.uuid),
      read: CourseFormValues(editing: course), failedItem: failedItem)
  }

  private func form(_ model: RecordSheetModel<CourseFormValues>) -> some View {
    CourseSheetForm(
      model: model, lookups: LookupsModel(session: session), isPushed: true, onCreated: { _ in },
      onDeleted: onDeleted)
  }
}

#Preview {
  NavigationStack {
    CourseFormView(mode: .create)
  }
  .environment(Session.stub(transport: StubTransport(routes: [:])))
}
