import Foundation
import OpenDivingKit
import Testing

/// The site panel's tab names and information card over the `dive-site` fixture.
struct DiveSiteSummaryTests {
  static func site(_ changes: [String: Any] = [:]) throws -> DiveSiteRead {
    var object = try #require(
      JSONSerialization.jsonObject(with: KitFixture.data("dive-site")) as? [String: Any])
    object.merge(changes) { _, new in new }
    return try APICoding.decoder().decode(
      DiveSiteRead.self, from: JSONSerialization.data(withJSONObject: object))
  }

  @Test func aTabCountsWhatItHoldsAndSaysNothingOfNone() {
    #expect(DiveSiteSummary.counted("My dives", 3) == "My dives (3)")
    #expect(DiveSiteSummary.counted("Marine life", 0) == "Marine life")
  }

  @Test func theInformationCardHoldsEveryFieldTheSiteRecords() throws {
    // The fixture's location, and a site's tags, are the panel's head's, not the card's.
    #expect(DiveSiteSummary.info(try Self.site(), units: .metric).isEmpty)
    #expect(DiveSiteSummary.info(try Self.site(["tags": ["wall"]]), units: .metric).isEmpty)
    let info = DiveSiteSummary.info(
      try Self.site([
        "other_names": ["Bells", "The Bells"], "latitude": 28.57, "longitude": 34.53,
        "depth_from": 5, "depth_to": 30.5, "water_type": "fresh", "altitude": 420,
        "entry_types": ["shore", "boat"], "tags": ["wall"],
        "external_ids": [
          ["registry": "wikidata", "identifier": "Q123"],
          ["registry": "divesitedb", "identifier": "77"],
        ],
      ]), units: .metric)
    #expect(info.alsoKnownAs == "Bells, The Bells")
    #expect(info.coordinates == "28.57, 34.53")
    #expect(info.depth == "5 m – 30.5 m")
    #expect(info.waterType == "Fresh water")
    #expect(info.altitude == "420 m")
    #expect(info.entryTypes == "Shore, Boat")
    #expect(
      info.rows.map(\.label) == [
        "Also known as", "Coordinates", "Depth", "Water type", "Altitude", "Entry types",
      ])
    #expect(info.rows.filter(\.copiesOnTap).map(\.value) == ["28.57, 34.53"])
    #expect(
      info.registries == [
        .init(label: "Wikidata", identifier: "Q123", link: "https://www.wikidata.org/wiki/Q123"),
        .init(label: "divesitedb", identifier: "77", link: nil),
      ])
  }

  /// What the facts line leaves to go without saying, the card says where the site records it.
  @Test func theInformationCardShowsTheSeaAndSeaLevel() throws {
    let info = DiveSiteSummary.info(
      try Self.site(["water_type": "salt", "altitude": 0, "location": NSNull()]), units: .metric)
    #expect(info.waterType == VocabularyLabels.waterType("salt"))
    #expect(info.altitude == "0 m")
    #expect(!info.isEmpty)
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
