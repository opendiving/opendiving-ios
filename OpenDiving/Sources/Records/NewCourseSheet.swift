import OpenDivingKit
import SwiftUI

/// The web's *New Course* dialog: queues the course and hands back its ref, or reopens a
/// queued create the server refused (`failedItem`) and queues it again. Its dive centre and
/// instructor are picked from what the phone holds or made here.
struct NewCourseSheet: View {
  let failedItem: UUID?
  let onCreated: (RecordRef) -> Void

  @Environment(Session.self) private var session

  init(failedItem: UUID? = nil, onCreated: @escaping (RecordRef) -> Void) {
    self.failedItem = failedItem
    self.onCreated = onCreated
  }

  var body: some View {
    CourseSheetForm(
      model: RecordSheetModel(
        outbox: OutboxModel(session: session), values: CourseFormValues(),
        failedItem: failedItem),
      lookups: LookupsModel(session: session), onCreated: onCreated)
  }
}

private struct CourseSheetForm: View {
  @State var model: RecordSheetModel<CourseFormValues>
  @State var lookups: LookupsModel
  let onCreated: (RecordRef) -> Void

  var body: some View {
    RecordSheetForm(
      title: "New Course", isReopened: model.isReopened,
      failure: model.failure, saveError: model.saveError, save: save
    ) {
      TrainingFields(
        agencyRequired: false, agency: $model.values.agency,
        agencyOther: $model.values.agencyOther,
        start: .init(label: "Start date", field: "start_date", date: startDate),
        end: .init(label: "End date", field: "end_date", date: $model.values.endDate),
        contact: $model.values.contact, instructor: instructor,
        instructorNumber: $model.values.instructorNumber, lookups: lookups,
        message: { model.message($0) }
      ) {
        TextBox(
          label: "Course *", placeholder: "e.g. Advanced Nitrox + Decompression Procedures",
          text: $model.values.name, message: model.message("name"))
      } besideAgency: {
        Picker("Status *", selection: $model.values.status) {
          ForEach(FormVocabulary.courseStatuses, id: \.self) { status in
            Text(RecordSheetText.courseStatus(status)).tag(status)
          }
        }
      }
      RecordPeopleField(
        people: $model.values.people, rows: lookups.people, defaultRole: "student",
        excluded: model.values.instructor)
      Section {
        NotesField(
          placeholder: "Skills covered, conditions, anything worth remembering...",
          text: $model.values.notes,
          error: model.message("notes"))
      }
    }
  }

  /// Picking the instructor takes them off the people below.
  private var instructor: Binding<RecordRef?> {
    Binding(get: { model.values.instructor }, set: { model.values.pickInstructor($0) })
  }

  /// Moving the start past the end empties the end.
  private var startDate: Binding<CalendarDate?> {
    Binding(get: { model.values.startDate }, set: { model.values.pickStartDate($0) })
  }

  private func save() -> Bool {
    guard let ref = model.save() else { return false }
    onCreated(ref)
    return true
  }
}

#Preview {
  NewCourseSheet { _ in }
    .environment(Session.stub(transport: StubTransport(routes: [:])))
}
