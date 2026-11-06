import Foundation
import Testing

@testable import OpenDivingKit

/// The site sheet's place search against the web's `place-search.tsx`,
/// `location-search-dialog.tsx` and `useGeocodedLocation` at `opendiving-web` `d29d21e4`.
@MainActor
struct PlaceSearchTests {
  private static let osm =
    "[Data © OpenStreetMap contributors, ODbL 1.0.](https://osm.org/copyright)"

  private func site(
    _ name: String, id: String = "node/1", locality: String? = "South Sinai, Egypt",
    otherNames: [String] = []
  ) -> DiveSiteLookupItem {
    DiveSiteLookupItem(
      ref: .server(UUID(uuidString: "01a14b2e-0c3d-7a10-9f00-4b2b3c4d5e6f")!), name: name,
      otherNames: otherNames, latitude: 28.5722, longitude: 34.5372,
      location: locality.map { LocationRead(name: $0) },
      externalIds: [ExternalIdRead(registry: "openstreetmap", identifier: id)],
      owner: DiveSiteOwner.commons, saved: false, attribution: Self.osm)
  }

  private func page(_ sites: [DiveSiteLookupItem], hasMore: Bool = false)
    -> PaginatedListResponse<DiveSiteLookupItem>
  {
    PaginatedListResponse(
      data: sites, totalCount: sites.count, hasMore: hasMore, page: 1, itemsPerPage: 10)
  }

  private func place(
    _ location: String, name: String? = nil, region: String? = nil, country: String? = nil,
    source: String? = nil, sourceId: String? = nil
  ) -> GeocodeResult {
    GeocodeResult(
      latitude: 28.5, longitude: 34.5, location: location, name: name, attribution: Self.osm,
      country: country, region: region, source: source, sourceId: sourceId, bboxSouth: 28,
      bboxNorth: 29, bboxWest: 34, bboxEast: 35)
  }

  @Test func commonsRowsComeFirstAndAGeocodedCopyOfOneIsDropped() {
    let rows = PlaceSearch.siteRows(
      commons: [site("Blue Hole")],
      geocoded: [
        place(
          "Blue Hole, South Sinai, Egypt", name: "Blue Hole", source: "osm", sourceId: "node/1"),
        place("Dahab, South Sinai, Egypt", name: "Dahab", region: "South Sinai", country: "Egypt"),
      ], position: nil, units: .metric)
    #expect(rows.map(\.name) == ["Blue Hole", "Dahab"])
    #expect(rows.map(\.hint) == ["South Sinai, Egypt", "South Sinai, Egypt"])
  }

  @Test func aGeocodedRowStaysUnlessTheRecordNamesItsObject() {
    let other = place("Blue Hole", source: "osm", sourceId: "node/2")
    let unsourced = place("Canyon", sourceId: "node/1")
    let rows = PlaceSearch.siteRows(
      commons: [site("Blue Hole")], geocoded: [other, unsourced], position: nil, units: .metric)
    #expect(rows.count == 3)
  }

  @Test func aCommonsRowSaysAnotherNameWhereItIsAndHowFar() {
    let hint = PlaceSearch.commonsHint(
      site("砂辺", otherNames: ["Sunabe"]),
      position: DeviceLocation(latitude: 28.5722, longitude: 34.5272), units: .metric)
    #expect(hint == "Sunabe · South Sinai, Egypt · 977 m")
  }

  @Test func aCommonsRowSaysTheOtherNameTheSearchFoundItBy() {
    let row = site("砂辺", locality: nil, otherNames: ["Sunabe", "Seawall", "砂辺"])
    #expect(
      PlaceSearch.commonsHint(row, query: "seaw", position: nil, units: .metric) == "Seawall")
    #expect(PlaceSearch.commonsHint(row, query: "砂", position: nil, units: .metric) == "Sunabe")
    #expect(PlaceSearch.commonsHint(site("A", locality: nil), position: nil, units: .metric) == nil)
  }

  @Test func aGeocodedRowDropsAContextPartItsNameSays() {
    let country = PlaceSearch.geocodeLabel(
      place("Philippines", name: "Philippines", country: "Philippines"))
    #expect(country.name == "Philippines")
    #expect(country.context == nil)
    let address = PlaceSearch.geocodeLabel(place("12 Main St, Dahab, Egypt"))
    #expect(address.name == "12 Main St, Dahab, Egypt")
    #expect(address.context == nil)
  }

  @Test func aTripPartsRowReadsWhatAPickSaves() {
    let rows = PlaceSearch.placeRows([
      place("Moalboal, Cebu, Philippines", name: "Moalboal"),
      place("Moalboal, Cebu, Philippines", name: "Moalboal"),
    ])
    #expect(rows.map(\.name) == ["Moalboal, Cebu, Philippines"])
    if case .geocode(let result) = rows.first?.pick {
      #expect(PlaceSearch.location(of: result).bboxNorth == 29)
    }
  }

  @Test func aLookedUpPositionNamesTheLocationOrClearsOnlyANamedOne() {
    let named = PlaceSearch.adopting(.named(place("Dahab, Egypt")), current: nil)
    #expect(named?.location == LocationWrite(name: "Dahab, Egypt"))
    #expect(named?.credit == Self.osm)
    #expect(PlaceSearch.adopting(.nameless, current: LocationWrite(name: "Dahab")) != nil)
    #expect(PlaceSearch.adopting(.nameless, current: LocationWrite(name: "Dahab"))?.location == nil)
    #expect(PlaceSearch.adopting(.nameless, current: nil) == nil)
    #expect(PlaceSearch.adopting(.unknown, current: LocationWrite(name: "Dahab")) == nil)
  }

  @Test func onlyAPickerWithAMapOffersIt() {
    let site = PlaceSearchText.diveSite
    #expect(site.noMatches(hasMap: true) == "Nothing found, place the site on the map instead.")
    #expect(site.noMatches(hasMap: false) == "Nothing found.")
    #expect(
      site.searchError(hasMap: true)
        == "Couldn't reach the search, place the site on the map instead.")
    #expect(site.searchError(hasMap: false) == "Couldn't reach the search.")

    let part = PlaceSearchText.tripPart
    #expect(part.noMatches(hasMap: true) == "No places found, tap the map instead.")
    #expect(part.noMatches(hasMap: false) == "No places found.")
    #expect(
      part.searchError(hasMap: true) == "Couldn't reach the place search, tap the map instead.")

    #expect(
      LocationFailure.unavailable.message(hasMap: true)
        == "Your location could not be found. Search for a place, or tap the map.")
    #expect(
      LocationFailure.unavailable.message(hasMap: false)
        == "Your location could not be found. Search for a place.")
    #expect(
      LocationFailure.denied.message(hasMap: true) == LocationFailure.denied.message(hasMap: false))

    let paste = "Paste a “27.8506, 34.3136” pair into either field to fill both"
    #expect(CoordinateHint.diveSite == paste + ".")
    #expect(CoordinateHint.contact(hasMap: true) == paste + ", or place the contact on the map.")
    #expect(CoordinateHint.contact(hasMap: false) == paste + ".")
  }

  @Test func aPastedPairFillsBothBoxes() {
    #expect(PlaceSearch.coordinatePair("27.8506, 34.3136")! == ("27.8506", "34.3136"))
    #expect(PlaceSearch.coordinatePair(" -27.8506;34 ")! == ("-27.8506", "34"))
    #expect(PlaceSearch.coordinatePair("27.8506 -34.3136")! == ("27.8506", "-34.3136"))
    #expect(PlaceSearch.coordinatePair("-16,5") == nil)
    #expect(PlaceSearch.coordinatePair("27.8506") == nil)
    #expect(PlaceSearch.coordinatePair("27.8506, 34.3136, 1") == nil)
  }

  @Test func aPositionNeedsBothBoxesInRange() {
    #expect(
      PlaceSearch.position(latitude: "28,5", longitude: "-34.5")
        == DeviceLocation(latitude: 28.5, longitude: -34.5))
    #expect(PlaceSearch.position(latitude: "91", longitude: "34") == nil)
    #expect(PlaceSearch.position(latitude: "28", longitude: "") == nil)
  }

  @Test func aCoordinateReadsAsTheShortestDecimal() {
    #expect(PlaceSearch.coordinateText(28.5722) == "28.5722")
    #expect(PlaceSearch.coordinateText(0.00001) == "0.00001")
    #expect(PlaceSearch.coordinateText(nil) == "")
  }

  @Test func aPlacedPositionStopsAtSixDecimals() {
    #expect(PlaceSearch.placedText(28.123456789) == "28.123457")
    #expect(PlaceSearch.placedText(-34.5) == "-34.5")
  }

  @Test func aLookedUpCreditIsKeptOnce() {
    let model = PlaceSearchModel(text: .tripPart, commons: nil, geocode: { _ in [] })
    model.owe(Self.osm)
    model.owe(Self.osm)
    model.owe("")
    #expect(model.attributions == [Self.osm])
  }

  // MARK: The search box

  private struct Down: Error {}

  @Test func oneSourceDownIsAShorterListAndBothDownIsAnError() async {
    let commonsOnly = PlaceSearchModel(
      text: .diveSite,
      commons: { _, _ in self.page([self.site("Blue Hole")], hasMore: true) },
      geocode: { _ in throw Down() }, debounce: .zero)
    await commonsOnly.search("blue", near: nil, units: .metric)
    #expect(
      commonsOnly.state
        == .results(
          PlaceSearch.siteRows(
            commons: [site("Blue Hole")], geocoded: [], query: "blue", position: nil,
            units: .metric),
          hasMore: true))
    #expect(commonsOnly.attributions == [Self.osm])

    let neither = PlaceSearchModel(
      text: .diveSite, commons: { _, _ in throw Down() }, geocode: { _ in throw Down() },
      debounce: .zero)
    await neither.search("blue", near: nil, units: .metric)
    #expect(neither.state == .failed)
  }

  @Test func aSitesPlacesAloneAreLabelledAsTheCombinedSearchLabelsThem() async {
    let model = PlaceSearchModel(
      text: .diveSitePlace, commons: nil,
      geocode: { _ in
        [self.place("Dahab, South Sinai, Egypt", name: "Dahab", country: "Egypt")]
      }, debounce: .zero)
    await model.search("dahab", near: nil, units: .metric)
    guard case .results(let rows, hasMore: false) = model.state else {
      Issue.record("No rows")
      return
    }
    #expect(rows.map(\.name) == ["Dahab"])
    #expect(rows.map(\.hint) == ["Egypt"])
  }

  @Test func bothSourcesAreAskedAtOnce() async {
    var geocoderAsked = false
    var overlapped = false
    let model = PlaceSearchModel(
      text: .diveSite,
      commons: { _, _ in
        for _ in 0..<200 where !geocoderAsked { try await Task.sleep(for: .milliseconds(5)) }
        overlapped = geocoderAsked
        return self.page([])
      },
      geocode: { _ in
        geocoderAsked = true
        return []
      }, debounce: .zero)
    await model.search("blue", near: nil, units: .metric)
    #expect(overlapped)
  }

  @Test func aShortOrLongQueryAsksNeitherSource() async {
    var asked = 0
    let model = PlaceSearchModel(
      text: .tripPart, commons: nil,
      geocode: { _ in
        asked += 1
        return []
      }, debounce: .zero)
    await model.search(" b ", near: nil, units: .metric)
    #expect(model.state == .idle)
    await model.search(String(repeating: "b", count: 201), near: nil, units: .metric)
    #expect(model.state == .tooLong)
    await model.search("bb", near: nil, units: .metric)
    #expect(model.state == .noMatches)
    #expect(asked == 1)
  }
}
