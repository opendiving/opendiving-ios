import OpenDivingKit
import SwiftUI

/// Who the diver was with, each with a role on this dive — a buddy until the diver says
/// otherwise — and the picker, whose Return creates a person of the name typed.
struct PeopleField: View {
  let model: DiveFormModel

  @State private var picking = false

  var body: some View {
    let people = model.values.people
    VStack(alignment: .leading, spacing: 8) {
      FieldLabel(DiveFormField.people.label)
      ForEach(people, id: \.person) { reference in
        let row = model.row(reference.person, .people)
        VStack(alignment: .leading, spacing: 4) {
          HStack {
            PickerRowLabel(row: row)
            Button {
              model.removePerson(reference.person)
            } label: {
              Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Remove \(row.title)")
          }
          Picker(
            "Role of \(row.title)",
            selection: Binding(
              get: { reference.role }, set: { model.setRole($0, of: reference.person) })
          ) {
            Text("No role").tag(String?.none)
            ForEach(roles(reference.role), id: \.self) { role in
              Text(VocabularyLabels.personRole(role)).tag(String?.some(role))
            }
          }
          .labelsHidden()
        }
      }
      Button(FormPicker.people.placeholder(holdsSome: !people.isEmpty)) { picking = true }
        .buttonStyle(.borderless)
    }
    .sheet(isPresented: $picking) {
      RecordPickerSheet(
        model: model, picker: .people, onSubmitText: submit
      ) { ref in
        if let ref { model.addPerson(ref) }
      }
    }
  }

  /// Return in the picker: the person of exactly that name where the phone lists one, else a
  /// new person of the name typed.
  private func submit(_ text: String) -> Bool {
    let name = text.trimmingCharacters(in: .whitespaces).lowercased()
    if let match = model.rows(.people, matching: text).first(where: {
      $0.title.lowercased() == name
    }) {
      model.addPerson(match.ref)
      return true
    }
    return model.addPerson(named: text)
  }

  /// The roles in the web's order, and one a newer server stored kept on offer.
  private func roles(_ current: String?) -> [String] {
    guard let current, !FormVocabulary.personRoles.contains(current) else {
      return FormVocabulary.personRoles
    }
    return FormVocabulary.personRoles + [current]
  }
}

#Preview {
  Form {
    PeopleField(model: DiveFormModel(session: DivePreviewData.session, mode: .create))
  }
}
