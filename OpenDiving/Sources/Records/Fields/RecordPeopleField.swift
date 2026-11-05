import OpenDivingKit
import SwiftUI

/// The people on a trip or a course, the rows and the picker the dive form has: picked from the
/// diver's people or added as a new person, who joins with `defaultRole`.
struct RecordPeopleField: View {
  @Binding var people: [PersonReference]
  let rows: [PersonLookupItem]
  /// The role a person joins with; nil for none, as on a trip.
  let defaultRole: String?
  /// Someone the form names elsewhere, a course's instructor, is not offered here.
  var excluded: RecordRef?

  var body: some View {
    Section {
      PeopleRows(people: $people, row: row) {
        PickerSheet(
          title: FormPicker.people.placeholder(holdsSome: false),
          searchPrompt: FormPicker.people.searchPrompt,
          rows: { LookupsModel.matching(offered, $0).map(FormPickerRow.init) },
          emptySentence: { $0.isEmpty ? "No people yet." : "No people found." },
          addLabel: FormPicker.people.addLabel,
          addSheet: { NewPersonSheet(onCreated: $0) },
          onPick: { ref in
            if let ref { join(ref) }
          })
      }
    } header: {
      FormSectionHeader(group: .people)
    }
  }

  private var offered: [PersonLookupItem] {
    rows.filter { row in row.ref != excluded && !people.contains { $0.person == row.ref } }
  }

  private func join(_ ref: RecordRef) {
    guard !people.contains(where: { $0.person == ref }) else { return }
    people.append(PersonReference(person: ref, role: defaultRole))
  }

  private func row(_ ref: RecordRef) -> FormPickerRow {
    rows.first { $0.ref == ref }.map(FormPickerRow.init)
      ?? FormPickerRow(ref: ref, title: "New person")
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
