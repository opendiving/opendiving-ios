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
    _ name: String, id: String = "node/1", region: String? = "South Sinai",
    country: String? = "Egypt", nameEn: String? = nil, held: DiveSiteReference? = nil
  ) -> DiveSiteSuggestion {
    DiveSiteSuggestion(
      name: name, nameEn: nameEn, latitude: 28.5722, longitude: 34.5372, country: country,
      region: region, source: "osm", sourceId: id, attribution: Self.osm,
      externalId: ExternalIdRead(registry: "openstreetmap", identifier: id), heldSite: held)
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

  @Test func catalogueRowsComeFirstAndAGeocodedCopyOfOneIsDropped() {
    let rows = PlaceSearch.siteRows(
      catalog: [site("Blue Hole")],
      geocoded: [
        place(
          "Blue Hole, South Sinai, Egypt", name: "Blue Hole", source: "osm", sourceId: "node/1"),
        place("Dahab, South Sinai, Egypt", name: "Dahab", region: "South Sinai", country: "Egypt"),
      ], position: nil, units: .metric)
    #expect(rows.map(\.name) == ["Blue Hole", "Dahab"])
    #expect(rows.map(\.hint) == ["South Sinai, Egypt", "South Sinai, Egypt"])
  }

  @Test func aCatalogueRowSaysItIsHeldItsEnglishNameAndHowFar() {
    let held = DiveSiteReference(uuid: UUID(), name: "Bells")
    let hint = PlaceSearch.catalogHint(
      site("砂辺", nameEn: "Sunabe", held: held),
      position: DeviceLocation(latitude: 28.5722, longitude: 34.5272), units: .metric)
    #expect(hint == "In your sites as Bells · Sunabe · South Sinai, Egypt · 977 m")
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

  @Test func aPickReplacesTheEntryThePreviousPickAdded() {
    let kept = ExternalIdWrite(registry: "wikidata", identifier: "Q1")
    let first = PlaceSearch.pickExternalId(
      [kept], replacing: nil, with: ExternalIdRead(registry: "openstreetmap", identifier: "node/1"))
    let second = PlaceSearch.pickExternalId(
      first.externalIds, replacing: first.added,
      with: ExternalIdRead(registry: "openstreetmap", identifier: "node/2"))
    #expect(
      second.externalIds == [
        kept, ExternalIdWrite(registry: "openstreetmap", identifier: "node/2"),
      ])
    let again = PlaceSearch.pickExternalId(
      [kept], replacing: nil, with: ExternalIdRead(registry: "wikidata", identifier: "Q1"))
    #expect(again.externalIds == [kept])
    #expect(again.added == nil)
  }

  @Test func aCataloguePickNamesItsPlaceOnlyWhereTheRecordHasOne() {
    #expect(PlaceSearch.location(of: site("A"))?.name == "South Sinai, Egypt")
    #expect(PlaceSearch.location(of: site("A", region: nil, country: nil)) == nil)
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

  // MARK: The search box

  private struct Down: Error {}

  @Test func oneSourceDownIsAShorterListAndBothDownIsAnError() async {
    let catalogOnly = PlaceSearchModel(
      text: .diveSite,
      catalog: { _, _ in DiveSiteSuggestResponse(results: [self.site("Blue Hole")], hasMore: true)
      },
      geocode: { _ in throw Down() }, debounce: .zero)
    await catalogOnly.search("blue", near: nil, units: .metric)
    #expect(
      catalogOnly.state
        == .results(
          PlaceSearch.siteRows(
            catalog: [site("Blue Hole")], geocoded: [], position: nil, units: .metric),
          hasMore: true))
    #expect(catalogOnly.attributions == [Self.osm])

    let neither = PlaceSearchModel(
      text: .diveSite, catalog: { _, _ in throw Down() }, geocode: { _ in throw Down() },
      debounce: .zero)
    await neither.search("blue", near: nil, units: .metric)
    #expect(neither.state == .failed)
  }

  @Test func aShortOrLongQueryAsksNeitherSource() async {
    var asked = 0
    let model = PlaceSearchModel(
      text: .tripPart, catalog: nil,
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
