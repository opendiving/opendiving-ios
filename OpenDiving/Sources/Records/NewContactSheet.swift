import OpenDivingKit
import SwiftUI

/// The web's *New Contact* dialog, opened from a dive's dive-centre picker with that role
/// ticked: queues the contact and hands back its ref, or reopens a queued create the server
/// refused (`failedItem`) and queues it again.
struct NewContactSheet: View {
  let failedItem: UUID?
  let onCreated: (RecordRef) -> Void
  var roles = ContactFormValues.diveCenterRoles

  @Environment(Session.self) private var session

  init(failedItem: UUID? = nil, onCreated: @escaping (RecordRef) -> Void) {
    self.failedItem = failedItem
    self.onCreated = onCreated
  }

  /// Opens with other roles ticked: a course's school, a trip part's place to stay.
  init(roles: [String], onCreated: @escaping (RecordRef) -> Void) {
    self.init(onCreated: onCreated)
    self.roles = roles
  }

  var body: some View {
    ContactSheetForm(
      model: RecordSheetModel(
        outbox: OutboxModel(session: session), values: ContactFormValues(roles: roles),
        failedItem: failedItem),
      onCreated: onCreated)
  }
}

private struct ContactSheetForm: View {
  @State var model: RecordSheetModel<ContactFormValues>
  let onCreated: (RecordRef) -> Void

  @State private var mapOpen = false

  private static let coordinateHint =
    "Paste a “27.8506, 34.3136” pair into either field to fill both, or place the contact on the map."

  var body: some View {
    RecordSheetForm(
      title: "New Contact", createLabel: "Create contact", isReopened: model.isReopened,
      failure: model.failure, saveError: model.saveError, save: save
    ) {
      Section {
        TextBox(
          label: "Name *", placeholder: "e.g. Blue Ocean Dive Center", text: $model.values.name,
          message: model.message("name"))
      }
      Section("Roles") {
        ForEach(FormVocabulary.contactRoles, id: \.self) { role in
          Toggle(RecordSheetText.contactRole(role), isOn: ticked(role))
        }
      }
      Section {
        TextBox(
          label: "Phone", text: $model.values.phone, message: model.message("phone"),
          keyboard: .phonePad)
        TextBox(
          label: "Email", text: $model.values.email, message: model.message("email"),
          keyboard: .emailAddress, verbatim: true)
        TextBox(
          label: "Website", placeholder: "e.g. blueocean.com", text: $model.values.website,
          message: model.message("website"), keyboard: .URL, verbatim: true)
      }
      Section {
        TextBox(
          label: "Address", placeholder: "Street, number, building, unit",
          text: $model.values.street, message: model.message("address", member: "street"))
        TextBox(
          label: "City", text: $model.values.city,
          message: model.message("address", member: "city"))
        TextBox(
          label: "Postcode", text: $model.values.postcode,
          message: model.message("address", member: "postcode"))
        TextBox(
          label: "Region", text: $model.values.region,
          message: model.message("address", member: "region"))
        TextBox(
          label: hasAddress ? "Country *" : "Country", text: $model.values.country,
          message: model.message("address", member: "country"))
      }
      Section {
        CoordinateFields(
          latitude: $model.values.latitude, longitude: $model.values.longitude,
          latitudeMessage: model.message("latitude"),
          longitudeMessage: model.message("longitude"), hint: Self.coordinateHint)
        if mapOpen {
          PinMap(
            name: "the contact", latitude: model.values.latitude,
            longitude: model.values.longitude
          ) { latitude, longitude in
            model.values.latitude = latitude
            model.values.longitude = longitude
          }
        } else {
          Button("Show map", systemImage: "mappin") { mapOpen = true }
        }
      }
      Section {
        TextBox(
          label: "Notes", placeholder: "Opening hours, who to ask for, what to bring...",
          text: $model.values.notes, message: model.message("notes"), multiline: true)
      }
    }
  }

  /// A country is asked for once any part of an address is.
  private var hasAddress: Bool {
    [
      model.values.street, model.values.city, model.values.postcode, model.values.region,
      model.values.country,
    ].contains { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
  }

  private func ticked(_ role: String) -> Binding<Bool> {
    Binding(
      get: { model.values.roles.contains(role) }, set: { model.values.setRole(role, $0) })
  }

  private func save() -> Bool {
    guard let ref = model.save() else { return false }
    onCreated(ref)
    return true
  }
}

#Preview {
  NewContactSheet { _ in }
    .environment(Session.stub(transport: StubTransport(routes: [:])))
}
