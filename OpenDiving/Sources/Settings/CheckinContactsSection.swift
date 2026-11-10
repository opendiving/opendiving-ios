import OpenDivingKit
import SwiftUI

/// *Emergency Contacts*: in call order, each a row that drags to a new place and swipes away.
struct CheckinContactsSection: View {
  @Bindable var model: CheckinDetailsModel

  var body: some View {
    let contacts = model.draft.emergencyContacts
    CheckinGroupSection(model: model, group: .emergency) {
      if contacts.isEmpty {
        Text("No emergency contacts yet.").foregroundStyle(.secondary)
      }
      SortableRows(
        items: $model.draft.emergencyContacts, identity: \.id,
        title: { $0.name.isEmpty ? "Contact" : $0.name },
        row: { _, contact in row(contact.id, movable: contacts.count > 1) })
      if model.canAddRow(to: .emergency) {
        Button("Add a contact") { model.draft.emergencyContacts.append(.init()) }
          .accentRow()
      }
    }
  }

  private func row(_ id: UUID, movable: Bool) -> some View {
    let contact = binding(id)
    return VStack(alignment: .leading, spacing: 12) {
      TextBox(
        label: "Name", text: contact.name, message: model.problems[.contactName(id)],
        contentType: .name)
      TextBox(
        label: "Phone number", text: contact.phone, message: model.problems[.contactPhone(id)],
        keyboard: .phonePad, contentType: .telephoneNumber)
      TextBox(
        label: "Relationship to you", placeholder: "Partner, parent, friend…",
        text: contact.relationship, message: model.problems[.contactRelationship(id)])
      HStack {
        Button("Remove") { model.draft.emergencyContacts.removeAll { $0.id == id } }
          .dangerRow()
          .buttonStyle(.borderless)
          .accessibilityLabel(
            "Remove \(contact.wrappedValue.name.isEmpty ? "contact" : contact.wrappedValue.name)")
        Spacer()
        if movable { DragHandle() }
      }
    }
    .padding(.vertical, 4)
  }

  /// By identity, as the rows may have moved since the row drew.
  private func binding(_ id: UUID) -> Binding<CheckinDetailsDraft.Contact> {
    Binding(
      get: { model.draft.emergencyContacts.first { $0.id == id } ?? .init(id: id) },
      set: { contact in
        guard let index = model.draft.emergencyContacts.firstIndex(where: { $0.id == id })
        else { return }
        model.draft.emergencyContacts[index] = contact
      })
  }
}

#Preview {
  Form {
    CheckinContactsSection(
      model: CheckinDetailsModel(session: Session.stub(transport: StubTransport(routes: [:]))))
  }
}
