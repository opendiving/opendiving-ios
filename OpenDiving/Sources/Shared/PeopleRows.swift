import OpenDivingKit
import SwiftUI

/// Who a dive, a trip or a course names, each a row of the form that drags to a new place and swipes
/// away with their role beside the name, then the row that opens `picker`.
struct PeopleRows<PickerSheetView: View>: View {
  @Binding var people: [PersonReference]
  let row: (RecordRef) -> FormPickerRow
  @ViewBuilder let picker: () -> PickerSheetView

  @State private var picking = false

  var body: some View {
    ForEach(Array(people.enumerated()), id: \.element.person) { index, reference in
      let row = row(reference.person)
      HStack {
        PickerRowLabel(row: row)
          .lineLimit(1)
        Picker("Role of \(row.title)", selection: role(of: reference)) {
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
          Button("Move \(row.title) up") { people.swapAt(index, index - 1) }
        }
        if index < people.count - 1 {
          Button("Move \(row.title) down") { people.swapAt(index, index + 1) }
        }
      }
      .swipeToDelete { people.removeAll { $0.person == reference.person } }
    }
    .onMove { people.move(fromOffsets: $0, toOffset: $1) }
    Button(FormPicker.people.placeholder(holdsSome: !people.isEmpty)) { picking = true }
      .accentRow()
      .sheet(isPresented: $picking, content: picker)
  }

  private func role(of reference: PersonReference) -> Binding<String?> {
    Binding(
      get: { reference.role },
      set: { role in
        guard let index = people.firstIndex(where: { $0.person == reference.person }) else {
          return
        }
        people[index].role = role
      })
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
  @Previewable @State var people: [PersonReference] = []
  Form {
    PeopleRows(people: $people, row: { FormPickerRow(ref: $0, title: "Ana Diaz") }) {
      Text("Picker")
    }
  }
}
