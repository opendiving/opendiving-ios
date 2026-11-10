import OpenDivingKit
import SwiftUI

/// The fields a course's form and a certification's share, as the web's one component draws
/// them: the agency and the field beside it, the agency's name for *Other*, the training's two
/// dates, the dive centre, the instructor and their number. Each form passes its own pair of
/// dates, and bindings that already carry its rules — moving the start past the end, picking
/// the instructor off the people.
struct TrainingFields<Leading: View, BesideAgency: View>: View {
  /// A card always names its agency; a course run by a private instructor need not, and offers
  /// *No agency*.
  let agencyRequired: Bool
  @Binding var agency: String?
  @Binding var agencyOther: String
  let start: TrainingDate
  let end: TrainingDate
  @Binding var contact: RecordRef?
  @Binding var instructor: RecordRef?
  @Binding var instructorNumber: String
  let lookups: LookupsModel
  /// The form's message for an API field name, as `RecordSheetModel.message(_:)`.
  let message: (String) -> String?
  /// The form's own rows ahead of the agency, in its section: the record's name.
  @ViewBuilder let leading: Leading
  @ViewBuilder let besideAgency: BesideAgency

  /// One of the two dates: its label, its field name for the form's messages, and its value.
  struct TrainingDate {
    let label: String
    let field: String
    let date: Binding<CalendarDate?>
  }

  var body: some View {
    Section {
      leading
      Picker(agencyRequired ? "Agency *" : "Agency", selection: $agency) {
        if !agencyRequired {
          Text("No agency").tag(String?.none)
        }
        ForEach(FormVocabulary.certificationAgencies, id: \.self) { agency in
          Text(VocabularyLabels.certificationAgency(agency) ?? agency).tag(Optional(agency))
        }
      }
      FieldMessage(message("agency"))
      besideAgency
      if agency == "other" {
        TextBox(
          label: "Agency name *", placeholder: "e.g. SwedTech Diving", text: $agencyOther,
          message: message("agency_other"))
      }
    }
    Section {
      CalendarDateField(label: start.label, date: start.date, rangeEnd: end.date.wrappedValue)
      FieldMessage(message(start.field))
      CalendarDateField(label: end.label, date: end.date, rangeStart: start.date.wrappedValue)
      FieldMessage(message(end.field))
    }
    Section {
      RecordPicker(
        label: "Dive center", placeholder: "Select a dive center...",
        searchPrompt: FormPicker.contact.searchPrompt,
        addLabel: "Add dive center...", rows: lookups.contacts, selection: $contact
      ) { made in
        NewContactSheet(roles: ["school"], onCreated: made)
      }
      RecordPicker(
        label: "Instructor", placeholder: "Select an instructor...",
        searchPrompt: "Search instructors...",
        addLabel: "Add instructor...", rows: lookups.people, selection: $instructor
      ) { made in
        NewPersonSheet(onCreated: made)
      }
      TextBox(
        label: "Instructor number", text: $instructorNumber,
        message: message("instructor_number"))
    }
  }
}

#Preview {
  @Previewable @State var values = CourseFormValues()
  let session = Session.stub(transport: StubTransport(routes: [:]))
  Form {
    TrainingFields(
      agencyRequired: false, agency: $values.agency, agencyOther: $values.agencyOther,
      start: .init(label: "Start date", field: "start_date", date: $values.startDate),
      end: .init(label: "End date", field: "end_date", date: $values.endDate),
      contact: $values.contact, instructor: $values.instructor,
      instructorNumber: $values.instructorNumber, lookups: LookupsModel(session: session),
      message: { _ in nil }
    ) {
      TextBox(label: "Course *", text: $values.name)
    } besideAgency: {
      Picker("Status *", selection: $values.status) {
        ForEach(FormVocabulary.courseStatuses, id: \.self) { status in
          Text(RecordSheetText.courseStatus(status)).tag(status)
        }
      }
    }
  }
  .environment(session)
}
