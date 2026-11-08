import Foundation
import Testing

@testable import OpenDivingKit

/// What the finder's rows say, and the fonts its cluster counts are drawn in.
struct SiteFinderRowContentTests {
  @Test func aSiteSaysHowFarItIsAndACommonsOneOwesItsCredit() throws {
    let rows = try KitFixture.decode(DiveSiteSearchPage.self, "dive-site-search").rows
    let own = SiteFinderRowContent(rows[0], units: .metric)
    #expect(own.title == "Canyon")
    #expect(own.subtitle == "Dahab, South Sinai, Egypt")
    #expect(own.distance == "4.2 km")
    #expect(!own.isCommons)
    #expect(own.credit == nil)
    let commons = SiteFinderRowContent(rows[1], units: .imperial)
    #expect(commons.isCommons)
    #expect(commons.credit?.contains("OpenStreetMap") == true)
    #expect(commons.distance == "1457.1 mi")
  }

  @Test func aPlaceSaysHowManySitesAreNearAndItsCreditGoesOnce() throws {
    let rows = try KitFixture.decode(DiveSiteSearchPage.self, "dive-site-search").rows
    let place = SiteFinderRowContent(rows[2], units: .metric)
    #expect(place.isPlace)
    #expect(place.title == "Canyon City")
    #expect(place.subtitle == "Canyon City, Colorado, United States")
    #expect(place.nearby == "No sites nearby")
    #expect(SiteFinderRowContent.nearby(1) == "1 site nearby")
    #expect(SiteFinderRowContent.nearby(15) == "15 sites nearby")
    #expect(SiteFinderRowContent.placeCredits(rows + [rows[2]]).count == 1)
  }

  @Test func aYourSitesCardShowsTheRowsFigures() throws {
    let rows = try KitFixture.decode(DiveSiteSearchPage.self, "dive-site-search").rows
    guard case .site(let item) = rows[0] else {
      Issue.record("not a site")
      return
    }
    let card = DiveSiteSummary.card(item, units: .metric)
    #expect(card.figures.map(\.value) == ["3", "31 m", "7"])
    #expect(card.points.count == 1)
  }

  @Test func clusterCountsUseTheStylesOwnFont() {
    let style = """
      {"version":8,"layers":[
        {"id":"water","type":"fill"},
        {"id":"label","type":"symbol","layout":{"text-font":["Noto Sans Regular"]}}
      ]}
      """
    #expect(MapStyleFonts.textFont(in: style) == ["Noto Sans Regular"])
    #expect(MapStyleFonts.textFont(in: #"{"version":8,"layers":[]}"#) == nil)
    #expect(
      MapStyleFonts.textFont(
        in: #"{"layers":[{"layout":{"text-font":["literal",["Noto Sans Bold"]]}}]}"#) == nil)
  }
}
