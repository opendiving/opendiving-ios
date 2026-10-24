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
      title: "New Course", createLabel: "Create course", isReopened: model.isReopened,
      failure: model.failure, saveError: model.saveError, save: save
    ) {
      Section {
        TextBox(
          label: "Course *", placeholder: "e.g. Advanced Nitrox + Decompression Procedures",
          text: $model.values.name, message: model.message("name"))
        Picker("Agency", selection: $model.values.agency) {
          Text("No agency").tag(String?.none)
          ForEach(FormVocabulary.certificationAgencies, id: \.self) { agency in
            Text(VocabularyLabels.certificationAgency(agency) ?? agency).tag(Optional(agency))
          }
        }
        Picker("Status *", selection: $model.values.status) {
          ForEach(FormVocabulary.courseStatuses, id: \.self) { status in
            Text(RecordSheetText.courseStatus(status)).tag(status)
          }
        }
        if model.values.agency == "other" {
          TextBox(
            label: "Agency name *", placeholder: "e.g. FFESSM", text: $model.values.agencyOther,
            message: model.message("agency_other"))
        }
      }
      Section {
        CalendarDateField(label: "Start date", date: $model.values.startDate)
        CalendarDateField(label: "End date", date: $model.values.endDate)
        FieldMessage(text: model.message("end_date"))
      }
      Section {
        RecordPicker(
          label: "Dive center", placeholder: "Select a dive center...",
          addLabel: "Add dive center...", rows: lookups.contacts,
          selection: $model.values.contact
        ) { made in
          NewContactSheet(roles: ["school"], onCreated: made)
        }
        RecordPicker(
          label: "Instructor", placeholder: "Select an instructor...",
          addLabel: "Add instructor...", rows: lookups.people, selection: instructor
        ) { made in
          NewPersonSheet(onCreated: made)
        }
        TextBox(
          label: "Instructor number", text: $model.values.instructorNumber,
          message: model.message("instructor_number"))
      }
      PeopleField(
        people: $model.values.people, rows: lookups.people, defaultRole: "student",
        excluded: model.values.instructor)
      Section {
        TextBox(
          label: "Notes",
          placeholder: "Skills covered, conditions, anything worth remembering...",
          text: $model.values.notes, message: model.message("notes"), multiline: true)
      }
    }
  }

  /// Picking the instructor takes them off the people below.
  private var instructor: Binding<RecordRef?> {
    Binding(get: { model.values.instructor }, set: { model.values.pickInstructor($0) })
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
