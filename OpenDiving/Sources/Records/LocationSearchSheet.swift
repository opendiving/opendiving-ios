import OpenDivingKit
import SwiftUI

/// What *Use location* hands the site sheet: the position, and the place and its credit.
struct SearchedLocation {
  var latitude: String
  var longitude: String
  var location: LocationWrite?
  var credit: String?
}

/// What a Commons record picked in the search becomes, which follows where the site form was
/// opened. Choosing it creates nothing.
struct CommonsOffer {
  let label: (DiveSiteLookupItem) -> String
  let take: (DiveSiteLookupItem) -> Void
}

/// The web's *Search location* dialog: finds where a site is — by a dive site's or a place's
/// name, by coordinates, or on the map where there is one — without touching the site sheet
/// until *Use location*. A Commons row offers that record instead of a new site.
struct LocationSearchSheet: View {
  let latitude: String
  let longitude: String
  let location: LocationWrite?
  let onUse: (SearchedLocation) -> Void
  /// Nil lists places alone: an edit, or a form reopened on a refused create, has a record of
  /// the diver's to place, which a Commons record neither fills nor replaces.
  let commonsOffer: CommonsOffer?

  @Environment(Session.self) private var session

  var body: some View {
    LocationSearchForm(
      search: PlaceSearchModel(
        session: session, finds: commonsOffer == nil ? .sitePlaces : .commonsAndPlaces),
      map: MapStyleModel(session: session), session: session,
      initial: SearchedLocation(latitude: latitude, longitude: longitude, location: location),
      onUse: onUse, commonsOffer: commonsOffer)
  }
}

private struct LocationSearchForm: View {
  @State var search: PlaceSearchModel
  @State var map: MapStyleModel
  let session: Session
  let onUse: (SearchedLocation) -> Void
  let commonsOffer: CommonsOffer?

  @State private var picked: SearchedLocation
  @State private var query: String
  @State private var offered: DiveSiteLookupItem?
  @State private var lookup = PositionLookup()
  @Environment(\.dismiss) private var dismiss

  init(
    search: PlaceSearchModel, map: MapStyleModel, session: Session, initial: SearchedLocation,
    onUse: @escaping (SearchedLocation) -> Void, commonsOffer: CommonsOffer?
  ) {
    _search = State(initialValue: search)
    _map = State(initialValue: map)
    self.session = session
    self.onUse = onUse
    self.commonsOffer = commonsOffer
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
          hasMap: map.hasMap, onPick: pick,
          onTypeName: { picked.location = PlaceSearch.typedLocation($0) })
        if let offered, let commonsOffer {
          Section {
            PickerRowLabel(row: FormPickerRow(offered))
            Button(commonsOffer.label(offered)) {
              commonsOffer.take(offered)
              dismiss()
            }
            .accentRow()
          } footer: {
            if let attribution = offered.attribution {
              AttributionLine(credits: [attribution])
            }
          }
        }
        Section {
          CoordinateFields(
            latitude: $picked.latitude, longitude: $picked.longitude,
            latitudeMessage: nil, longitudeMessage: nil,
            hint: usable
              ? CoordinateHint.searchedSite(hasMap: map.hasMap)
              : "Enter both a latitude and a longitude in decimal degrees, or neither.",
            onPlaced: place)
          PinMap(
            style: map.shown, name: "the dive site", latitude: picked.latitude,
            longitude: picked.longitude, credit: credit, onPick: place)
        }
      }
      .navigationTitle("Search Location")
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
          .accentRow()
          .labelStyle(.titleOnly)
          .disabled(!usable)
        }
      }
      .showsMapStyle(map)
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
      offered = nil
      setPosition(result.latitude, result.longitude)
      picked.location = PlaceSearch.location(of: result)
      adopt(credit: result.attribution)
    case .commons(let site):
      offered = site
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
    commonsOffer: CommonsOffer(label: { "Use \($0.name)" }, take: { _ in })
  )
  .environment(Session.stub(transport: StubTransport(routes: [:])))
}
