import OpenDivingKit
import SwiftUI

/// Who the diver was with, each a row of the form that drags to a new place and swipes away, its
/// role on this dive beside the name — a buddy until the diver says otherwise — and the picker,
/// whose Return creates a person of the name typed.
struct PeopleField: View {
  let model: DiveFormModel

  @State private var picking = false

  var body: some View {
    let people = model.values.people
    ForEach(Array(people.enumerated()), id: \.element.person) { index, reference in
      let row = model.row(reference.person, .people)
      HStack {
        PickerRowLabel(row: row)
          .lineLimit(1)
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
        .fixedSize()
        if people.count > 1 { DragHandle() }
      }
      .accessibilityActions {
        if index > 0 {
          Button("Move \(row.title) up") { model.change { $0.people.swapAt(index, index - 1) } }
        }
        if index < people.count - 1 {
          Button("Move \(row.title) down") { model.change { $0.people.swapAt(index, index + 1) } }
        }
      }
      .swipeToDelete { model.removePerson(reference.person) }
    }
    .onMove { from, to in model.change { $0.people.move(fromOffsets: from, toOffset: to) } }
    Button(FormPicker.people.placeholder(holdsSome: !people.isEmpty)) { picking = true }
      .accentRow()
      .sheet(isPresented: $picking) {
        RecordPickerSheet(
          model: model, picker: .people, onSubmitText: { model.addPerson(named: $0) }
        ) { ref in
          if let ref { model.addPerson(ref) }
        }
      }
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
