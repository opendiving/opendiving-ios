import OpenDivingKit
import SwiftUI

/// What *Use location* hands the site sheet: the position, the place and its credit, and the
/// catalogue site last picked, which names the site and carries its registry entry.
struct SearchedLocation {
  var latitude: String
  var longitude: String
  var location: LocationWrite?
  var credit: String?
  var site: DiveSiteSuggestion?
}

/// The web's *Search location* dialog: finds where a site is — by a dive site's or a place's
/// name, by coordinates, or on the map — without touching the site sheet until *Use location*.
/// A catalogue row the diver already has a site for offers that site first.
struct LocationSearchSheet: View {
  let latitude: String
  let longitude: String
  let location: LocationWrite?
  let onUse: (SearchedLocation) -> Void
  /// The diver took the site they already have; nothing is created.
  let onTakeHeldSite: (UUID) -> Void

  @Environment(Session.self) private var session

  var body: some View {
    LocationSearchForm(
      search: PlaceSearchModel(session: session, findsSites: true), session: session,
      initial: SearchedLocation(latitude: latitude, longitude: longitude, location: location),
      onUse: onUse, onTakeHeldSite: onTakeHeldSite)
  }
}

private struct LocationSearchForm: View {
  @State var search: PlaceSearchModel
  let session: Session
  let onUse: (SearchedLocation) -> Void
  let onTakeHeldSite: (UUID) -> Void

  @State private var picked: SearchedLocation
  @State private var query: String
  @State private var offer: DiveSiteSuggestion?
  @State private var lookup = PositionLookup()
  @Environment(\.dismiss) private var dismiss

  init(
    search: PlaceSearchModel, session: Session, initial: SearchedLocation,
    onUse: @escaping (SearchedLocation) -> Void, onTakeHeldSite: @escaping (UUID) -> Void
  ) {
    _search = State(initialValue: search)
    self.session = session
    self.onUse = onUse
    self.onTakeHeldSite = onTakeHeldSite
    _picked = State(initialValue: initial)
    // A site with no position yet searches for its Location's name straight away.
    let placed = PlaceSearch.position(latitude: initial.latitude, longitude: initial.longitude)
    _query = State(initialValue: placed == nil ? initial.location?.name ?? "" : "")
  }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          LabeledContent("Location", value: picked.location?.name ?? "Not set")
        }
        PlaceSearchSection(
          model: search, query: $query, position: position, units: session.units,
          onPick: pick, onTypeName: { picked.location = PlaceSearch.typedLocation($0) })
        if let offer, let held = offer.heldSite {
          Section {
            Text("You already have **\(held.name)** for this site.")
            Button("Use \(held.name)") {
              onTakeHeldSite(held.uuid)
              dismiss()
            }
            Button("Make a new site") { fill(from: offer) }
          }
        }
        Section {
          CoordinateFields(
            latitude: $picked.latitude, longitude: $picked.longitude,
            latitudeMessage: nil, longitudeMessage: nil,
            hint: usable
              ? "Coordinates of the site, or place it on the map below."
              : "Enter both a latitude and a longitude in decimal degrees, or neither.",
            onPlaced: place)
          PinMap(
            name: "the dive site", latitude: picked.latitude, longitude: picked.longitude,
            credit: credit, onPick: place)
        }
      }
      .navigationTitle("Search location")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Use location", systemImage: "mappin") {
            var used = picked
            used.latitude = used.latitude.trimmingCharacters(in: .whitespaces)
            used.longitude = used.longitude.trimmingCharacters(in: .whitespaces)
            used.credit = credit
            onUse(used)
            dismiss()
          }
          .labelStyle(.titleOnly)
          .disabled(!usable)
        }
      }
      .task {
        // Opened on a placed site, the Location says what is there now.
        if position != nil { place(picked.latitude, picked.longitude) }
      }
    }
  }

  private var position: DeviceLocation? {
    PlaceSearch.position(latitude: picked.latitude, longitude: picked.longitude)
  }

  /// Both or neither, as the site sheet will insist on.
  private var usable: Bool {
    position != nil
      || (picked.latitude.trimmingCharacters(in: .whitespaces).isEmpty
        && picked.longitude.trimmingCharacters(in: .whitespaces).isEmpty)
  }

  private func pick(_ pick: PlacePick) {
    switch pick {
    case .geocode(let result):
      offer = nil
      picked.site = nil
      setPosition(result.latitude, result.longitude)
      picked.location = PlaceSearch.location(of: result)
      adopt(credit: result.attribution)
    case .catalog(let site) where site.heldSite != nil:
      offer = site
    case .catalog(let site):
      fill(from: site)
    }
  }

  /// The catalogue already resolved the place; a record with none leaves Location as it is.
  private func fill(from site: DiveSiteSuggestion) {
    offer = nil
    picked.site = site
    setPosition(site.latitude, site.longitude)
    if let place = PlaceSearch.location(of: site) {
      picked.location = place
      adopt(credit: site.attribution)
    } else {
      adopt(credit: nil)
    }
  }

  private func setPosition(_ latitude: Double, _ longitude: Double) {
    picked.latitude = PlaceSearch.coordinateText(latitude)
    picked.longitude = PlaceSearch.coordinateText(longitude)
  }

  /// A position that arrived without a name, tapped or pasted: the geocoder is asked what is
  /// there.
  private func place(_ latitude: String, _ longitude: String) {
    picked.latitude = latitude
    picked.longitude = longitude
    Task {
      await lookup.lookUp(
        session: session, latitude: latitude, longitude: longitude,
        current: { (picked.latitude, picked.longitude, picked.location) },
        apply: { picked.location = $0 })
    }
  }

  private var credit: String? {
    lookup.credit(latitude: picked.latitude, longitude: picked.longitude)
  }

  private func adopt(credit: String?) {
    lookup.adopt(latitude: picked.latitude, longitude: picked.longitude, credit: credit)
  }
}

#Preview {
  LocationSearchSheet(
    latitude: "", longitude: "", location: LocationWrite(name: "Dahab"), onUse: { _ in },
    onTakeHeldSite: { _ in }
  )
  .environment(Session.stub(transport: StubTransport(routes: [:])))
}
