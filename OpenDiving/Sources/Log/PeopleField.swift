import OpenDivingKit
import SwiftUI

/// Who the diver was with, a buddy until the diver says otherwise, and the picker, whose Return
/// creates a person of the name typed.
struct PeopleField: View {
  let model: DiveFormModel

  var body: some View {
    PeopleRows(
      people: Binding(
        get: { model.values.people }, set: { people in model.change { $0.people = people } }),
      row: { model.row($0, .people) },
      picker: {
        RecordPickerSheet(
          model: model, picker: .people, onSubmitText: { model.addPerson(named: $0) }
        ) { ref in
          if let ref { model.addPerson(ref) }
        }
      })
  }
}

#Preview {
  Form {
    PeopleField(model: DiveFormModel(session: DivePreviewData.session, mode: .create))
  }
}
