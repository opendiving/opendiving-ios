import Foundation
import Testing

@testable import OpenDivingKit

/// More's *Marine Life* card, a species' page and a *Your dive sites* row say what the web's
/// say, field for field.
struct MarineLifeContentTests {
  private func species(_ edit: (inout [String: Any]) -> Void = { _ in }) throws -> SpeciesRead {
    var object = try #require(
      JSONSerialization.jsonObject(with: KitFixture.data("species")) as? [String: Any])
    edit(&object)
    return try APICoding.decoder().decode(
      SpeciesRead.self, from: JSONSerialization.data(withJSONObject: object))
  }

  private func entries() throws -> [SpeciesLifeListEntry] {
    try KitFixture.decode(PaginatedListResponse<SpeciesLifeListEntry>.self, "species-life-list")
      .data
  }

  @Test func aLifeListCardCountsDivesAndSitesAndDatesTheLastSighting() throws {
    let card = SpeciesCardContent.marineLife(try entries()[0])
    #expect(card.commonName == "Twoband anemonefish")
    #expect(card.scientificName == "Amphiprion bicinctus")
    #expect(
      card.figures == [
        Figure(label: "Dives", value: "7"), Figure(label: "Dive sites", value: "3"),
        Figure(label: "Last seen", value: "Oct 2, 2026"),
      ])
  }

  @Test func theHeroNamesTheSpeciesAndCountsWhatTheHistoryVouchesFor() throws {
    let entry = try entries()[0]
    let seen = SpeciesPageContent(SpeciesPage(species: try species(), history: .seen(entry)))
    #expect(seen.hero.title == "Twoband anemonefish")
    #expect(seen.hero.facts.map(\.text) == ["Amphiprion bicinctus", "Species"])
    #expect(seen.hero.figures.map(\.label) == ["Dives", "Dive sites", "Last seen"])
    #expect(seen.dives.title == "Dives with Twoband anemonefish")

    let never = SpeciesPageContent(SpeciesPage(species: try species(), history: .never))
    #expect(
      never.hero.figures == [
        Figure(label: "Dives", value: "0"), Figure(label: "Dive sites", value: "0"),
      ])
    let unknown = SpeciesPageContent(SpeciesPage(species: try species(), history: .unknown))
    #expect(unknown.hero.figures.isEmpty)
  }

  @Test func aSpeciesWithNoCommonNameIsTitledByItsScientificOneOnce() throws {
    let family = try species {
      $0["common_name"] = NSNull()
      $0["scientific_name"] = "Muraenidae"
      $0["rank"] = "unknown"
    }
    let content = SpeciesPageContent(SpeciesPage(species: family, history: .never))
    #expect(content.hero.title == "Muraenidae")
    #expect(content.hero.facts.isEmpty)
  }

  @Test func theTaxonomyListsWhatTheCatalogRecordsAndLinksTheAphiaID() throws {
    let content = SpeciesPageContent(
      SpeciesPage(
        species: try species {
          $0["phylum"] = NSNull()
          $0["genus"] = ""
        }, history: .never))
    #expect(
      content.taxonomy.map(\.label) == ["Kingdom", "Class", "Order", "Family", "Authority"])
    #expect(content.aphiaID == "278400")
    #expect(
      content.aphiaURL?.absoluteString
        == "https://www.marinespecies.org/aphia.php?p=taxdetails&id=278400")
    #expect(
      SpeciesPageContent.taxonomyCredit.text
        == "Taxonomy: World Register of Marine Species, CC BY")
    #expect(content.photoCredit != nil)
    let bare = SpeciesPageContent(
      SpeciesPage(species: try species { $0["photo_sha256"] = NSNull() }, history: .never))
    #expect(bare.photoCredit == nil)
  }

  @Test func aSiteCardSaysWhatATripCardSays() throws {
    let page = try KitFixture.decode(DiveSiteSearchPage.self, "dive-site-search")
    let own = try #require(YourDiveSiteCardContent(page.rows[0], units: .metric))
    #expect(own.card.title == "Canyon")
    // Salt water and sea level go without saying.
    #expect(
      own.card.facts.map(\.text) == ["Dahab, South Sinai, Egypt", "12 m – 52 m", "Shore"])
    #expect(own.card.facts.map(\.accessibilityLabel) == [nil, "Depth", "Entry type"])
    #expect(
      own.card.figures == [
        Figure(label: "Dives", value: "3"), Figure(label: "Max depth", value: "31 m"),
        Figure(label: "Species seen", value: "7"),
      ])
    #expect(
      own.card.points == [MapPoint(name: "Canyon", latitude: 28.5687, longitude: 34.5372)])
    #expect(own.isWaitingForReview)
    #expect(!own.isCommons)
    #expect(own.credit == nil)

    let commons = try #require(YourDiveSiteCardContent(page.rows[1], units: .metric))
    #expect(commons.isCommons)
    #expect(
      commons.credit == "[Data © OpenStreetMap contributors, ODbL 1.0.](https://osm.org/copyright)")
    #expect(commons.card.figures.isEmpty)
  }

  @Test func aSiteCardPrintsFreshWaterAltitudeAndOneDive() {
    let item = DiveSiteSearchItem(
      site: DiveSiteLookupItem(
        ref: .server(UUID()), name: "Lake", waterType: "fresh", altitude: 1200,
        entryTypes: ["shore", "boat"]),
      depthTo: 18, dives: DiveSiteDives(diveCount: 1))
    let row = YourDiveSiteCardContent(.site(item), units: .metric)
    #expect(
      row?.card.facts.map(\.accessibilityLabel) == [
        "Water type", "Depth", "Altitude", "Entry types",
      ])
    #expect(row?.card.facts[1].text == "To 18 m")
    #expect(row?.card.figures == [Figure(label: "Dives", value: "1")])
    // No position, no pin: the card shows the water.
    #expect(row?.card.points.isEmpty == true)
  }
}
