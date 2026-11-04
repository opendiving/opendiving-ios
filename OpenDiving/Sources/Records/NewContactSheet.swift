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
      map: MapStyleModel(session: session), onCreated: onCreated)
  }
}

private struct ContactSheetForm: View {
  @State var model: RecordSheetModel<ContactFormValues>
  @State var map: MapStyleModel
  let onCreated: (RecordRef) -> Void

  @State private var mapOpen = false

  var body: some View {
    RecordSheetForm(
      title: "New Contact", isReopened: model.isReopened,
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
            .tint(.brandTeal)
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
          label: model.values.hasAddress ? "Country *" : "Country", text: $model.values.country,
          message: model.message("address", member: "country"))
      }
      Section {
        CoordinateFields(
          latitude: $model.values.latitude, longitude: $model.values.longitude,
          latitudeMessage: model.message("latitude"),
          longitudeMessage: model.message("longitude"),
          hint: CoordinateHint.contact(hasMap: map.hasMap))
        if let style = map.shown {
          if mapOpen {
            PinMap(
              style: style, name: "the contact", latitude: model.values.latitude,
              longitude: model.values.longitude
            ) { latitude, longitude in
              model.values.latitude = latitude
              model.values.longitude = longitude
            }
          } else {
            Button {
              mapOpen = true
            } label: {
              Label("Show map", icon: .mapPin)
            }
          }
        }
      }
      Section {
        TextBox(
          label: "Notes", placeholder: "Opening hours, who to ask for, what to bring...",
          text: $model.values.notes, message: model.message("notes"), multiline: true)
      }
    }
    .showsMapStyle(map)
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
