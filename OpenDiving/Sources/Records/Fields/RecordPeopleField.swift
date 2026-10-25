import OpenDivingKit
import SwiftUI

/// The people on a trip or a course, each with a role, as the web's people multi-select holds
/// them: picked from the diver's people or added as a new person, who joins with `defaultRole`.
struct RecordPeopleField: View {
  @Binding var people: [PersonReference]
  let rows: [PersonLookupItem]
  /// The role a person joins with; nil for none, as on a trip.
  let defaultRole: String?
  /// Someone the form names elsewhere, a course's instructor, is not offered here.
  var excluded: RecordRef?

  @State private var adding = false

  var body: some View {
    Section("People") {
      ForEach($people, id: \.person) { $reference in
        HStack {
          VStack(alignment: .leading) {
            Text(name(reference.person))
            if reference.person.isLocal { PendingMark() }
          }
          Spacer()
          Picker("Role of \(name(reference.person))", selection: $reference.role) {
            Text("No role").tag(String?.none)
            ForEach(FormVocabulary.personRoles, id: \.self) { role in
              Text(VocabularyLabels.personRole(role)).tag(Optional(role))
            }
          }
          .labelsHidden()
        }
      }
      .onDelete { people.remove(atOffsets: $0) }
      NavigationLink(people.isEmpty ? "Select a person..." : "Add another person...") {
        RecordPickerList(
          title: "People", rows: offered, selection: pick, addLabel: "Add person...",
          add: { adding = true })
      }
    }
    .sheet(isPresented: $adding) {
      NewPersonSheet { ref in join(ref) }
    }
  }

  private var offered: [PersonLookupItem] {
    rows.filter { row in row.ref != excluded && !people.contains { $0.person == row.ref } }
  }

  private var pick: Binding<RecordRef?> {
    Binding(get: { nil }, set: { ref in ref.map(join) })
  }

  private func join(_ ref: RecordRef) {
    guard !people.contains(where: { $0.person == ref }) else { return }
    people.append(PersonReference(person: ref, role: defaultRole))
  }

  private func name(_ ref: RecordRef) -> String {
    rows.first { $0.ref == ref }?.name ?? "New person"
  }
}

#Preview {
  @Previewable @State var people: [PersonReference] = []
  NavigationStack {
    Form {
      RecordPeopleField(people: $people, rows: [], defaultRole: "student")
    }
  }
  .environment(Session.stub(transport: StubTransport(routes: [:])))
}
