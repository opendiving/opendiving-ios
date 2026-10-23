import Foundation
import OpenDivingKit
import Testing

/// The site's card, hero and information card over the `dive-site` fixture, as the web's
/// `diveSiteFacts`, `DiveSiteCard`, `DiveSiteHero` and `DiveSiteInfoCard` print them.
struct DiveSiteSummaryTests {
  static func site(_ changes: [String: Any] = [:]) throws -> DiveSiteRead {
    var object = try #require(
      JSONSerialization.jsonObject(with: KitFixture.data("dive-site")) as? [String: Any])
    object.merge(changes) { _, new in new }
    return try APICoding.decoder().decode(
      DiveSiteRead.self, from: JSONSerialization.data(withJSONObject: object))
  }

  @Test func factsAreEachOnlyWhereTheSiteRecordsIt() throws {
    let site = try Self.site([
      "water_type": "fresh", "depth_from": 5, "depth_to": 30.5, "altitude": 420,
      "entry_types": ["shore", "boat"],
    ])
    #expect(
      DiveSiteSummary.facts(site, units: .metric) == [
        Fact(text: "Dahab, Egypt"),
        Fact(text: "Fresh water", systemImage: "water.waves", accessibilityLabel: "Water type"),
        Fact(text: "5 m – 30.5 m", systemImage: "arrow.down.to.line", accessibilityLabel: "Depth"),
        Fact(text: "420 m", systemImage: "mountain.2", accessibilityLabel: "Altitude"),
        Fact(
          text: "Shore, Boat", systemImage: "water.waves.and.arrow.down",
          accessibilityLabel: "Entry types"),
      ])
    let sea = try Self.site([
      "water_type": "salt", "depth_to": 30, "altitude": 0, "location": NSNull(),
    ])
    #expect(
      DiveSiteSummary.facts(sea, units: .metric) == [
        Fact(text: "To 30 m", systemImage: "arrow.down.to.line", accessibilityLabel: "Depth")
      ])
    let shallow = try Self.site(["depth_from": 5, "location": NSNull()])
    #expect(DiveSiteSummary.facts(shallow, units: .metric).map(\.text) == ["From 5 m"])
  }

  @Test func theCardShowsADashForNoDeepestAndTheHeroLeavesItOut() throws {
    let site = try Self.site(["max_dive_depth": NSNull(), "dive_count": 0])
    #expect(
      DiveSiteSummary.card(site, units: .metric).figures == [
        Figure(label: "Dives", value: "0"), Figure(label: "Deepest", value: nil),
      ])
    #expect(
      DiveSiteSummary.hero(site, units: .metric).figures == [
        Figure(label: "Dives", value: "0"), Figure(label: "Last dive", value: "Apr 17, 2026"),
      ])
  }

  @Test func theHeroCountsSpeciesAndMapsThePinAlone() throws {
    let site = try Self.site(["species_count": 4, "latitude": 28.57, "longitude": 34.53])
    let hero = DiveSiteSummary.hero(site, units: .metric)
    #expect(
      hero.figures == [
        Figure(label: "Dives", value: "2"), Figure(label: "Deepest", value: "46 m"),
        Figure(label: "Species seen", value: "4"),
        Figure(label: "Last dive", value: "Apr 17, 2026"),
      ])
    #expect(hero.points == [MapPoint(name: "Tiger Reef", latitude: 28.57, longitude: 34.53)])
    #expect(DiveSiteSummary.card(site, units: .metric).figures.count == 3)
    #expect(DiveSiteSummary.hero(try Self.site(["latitude": 28.57]), units: .metric).points == [])
  }

  @Test func theInformationCard() throws {
    #expect(DiveSiteSummary.info(try Self.site()).isEmpty)
    let info = DiveSiteSummary.info(
      try Self.site([
        "other_names": ["Bells", "The Bells"], "latitude": 28.57, "longitude": 34.53,
        "tags": ["wall"],
        "external_ids": [
          ["registry": "wikidata", "identifier": "Q123"],
          ["registry": "divesitedb", "identifier": "77"],
        ],
      ]))
    #expect(info.alsoKnownAs == "Bells, The Bells")
    #expect(info.coordinates == "28.57, 34.53")
    #expect(info.tags == ["wall"])
    #expect(
      info.registries == [
        .init(label: "Wikidata", identifier: "Q123", link: "https://www.wikidata.org/wiki/Q123"),
        .init(label: "divesitedb", identifier: "77", link: nil),
      ])
  }

  @Test func aLifeListRowAsASpeciesCard() throws {
    let page = try KitFixture.decode(
      PaginatedListResponse<SpeciesLifeListEntry>.self, "species-life-list")
    let named = SpeciesCardContent.lifeList(page.data[0])
    #expect(named.commonName == "Twoband anemonefish")
    #expect(named.scientificName == "Amphiprion bicinctus")
    #expect(
      named.figures == [
        Figure(label: "Dives", value: "7"), Figure(label: "Last seen", value: "Oct 2, 2026"),
      ])
    let family = SpeciesCardContent.lifeList(page.data[1])
    #expect(family.commonName == "Muraenidae")
    #expect(family.scientificName == "Muraenidae (Family)")
    #expect(family.figures.last == Figure(label: "Last seen", value: "Jun 18, 2002"))
  }
}
