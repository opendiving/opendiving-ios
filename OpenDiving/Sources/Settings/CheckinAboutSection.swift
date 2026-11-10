import OpenDivingKit
import SwiftUI

/// *About You*: the date of birth, the phone and the email the diver gives out. A field added to
/// the group goes inside this section, and rides its save.
struct CheckinAboutSection: View {
  @Bindable var model: CheckinDetailsModel

  var body: some View {
    CheckinGroupSection(model: model, group: .about) {
      VStack(alignment: .leading, spacing: 6) {
        CalendarDateField(label: "Date of birth", date: $model.draft.dateOfBirth)
        FieldMessage(model.problems[.dateOfBirth])
      }
      TextBox(
        label: "Phone number", text: $model.draft.phone, message: model.problems[.phone],
        keyboard: .phonePad, contentType: .telephoneNumber)
      VStack(alignment: .leading, spacing: 6) {
        TextBox(
          label: "Email", text: $model.draft.email, message: model.problems[.email],
          keyboard: .emailAddress, contentType: .emailAddress, verbatim: true)
        FieldMessage(
          "Printed on your check-in sheet and carried in your exports. The address you sign in"
            + " with stays private.",
          isNote: true)
        if let signIn = model.signInEmail, !model.draft.emailIs(signIn) {
          Button("Use my sign-in email") { model.draft.email = signIn }
            .accentRow()
            .buttonStyle(.borderless)
            .font(.footnote)
        }
      }
    }
  }
}

#Preview {
  Form {
    CheckinAboutSection(
      model: CheckinDetailsModel(session: Session.stub(transport: StubTransport(routes: [:]))))
  }
}
