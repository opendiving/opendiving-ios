import Foundation
import Testing

@testable import OpenDivingKit

/// What the finder's three routes and the trip lookup's parts decode to.
struct SiteFinderDecodingTests {
  @Test func aSearchPageHoldsSitesAndPlacesInOrderAndLeavesOutAKindItDoesNotKnow() throws {
    let page = try KitFixture.decode(DiveSiteSearchPage.self, "dive-site-search")
    #expect(page.rows.count == 3)
    #expect(page.hasMore)
    #expect(page.totalCount == nil)
    #expect(page.itemsPerPage == 25)
    guard case .site(let own) = page.rows[0], case .site(let commons) = page.rows[1],
      case .place(let place) = page.rows[2]
    else {
      Issue.record("rows out of order: \(page.rows)")
      return
    }
    #expect(own.name == "Canyon")
    #expect(own.match == "exact")
    #expect(own.distanceM == 4210.5)
    #expect(own.depthTo == 52)
    #expect(own.dives?.diveCount == 3)
    #expect(own.dives?.lastDivedOn == CalendarDate(year: 2026, month: 9, day: 14))
    #expect(own.isWaitingForReview)
    #expect(commons.site.isCommons)
    #expect(!commons.saved)
    #expect(commons.dives == nil)
    #expect(commons.otherNames == ["Canyon Reef"])
    #expect(place.place.name == "Canyon City")
    #expect(place.place.bboxWest == -105.3)
    #expect(place.sitesNearby == 0)
    #expect(place.distanceM == 432000)
  }

  @Test func aSiteRowThisBuildCannotReadFailsThePage() throws {
    let broken = try KitFixture.text("dive-site-search").replacingOccurrences(
      of: #""name": "Canyon","#, with: #""name": 7,"#)
    #expect(throws: DecodingError.self) {
      try APICoding.decoder().decode(DiveSiteSearchPage.self, from: Data(broken.utf8))
    }
  }

  @Test func aSearchRowSurvivesTheCacheRoundTrip() throws {
    let page = try KitFixture.decode(DiveSiteSearchPage.self, "dive-site-search")
    let again = try APICoding.decoder().decode(
      [DiveSiteSearchRow].self, from: APICoding.encoder().encode(page.rows))
    #expect(again == page.rows)
  }

  @Test func theReadersPointsAreArrays() throws {
    let points = try KitFixture.roundTrip(DiveSitePoints.self, "dive-site-points")
    #expect(points.points.map(\.name) == ["Canyon", "The Canyon"])
    #expect(points.points[0].longitude == 34.5372)
    #expect(points.points[0].latitude == 28.5687)
    #expect(!points.points[0].isCommons)
    #expect(points.points[1].isCommons)
  }

  @Test func theCommonsDocumentKeepsItsSourceKeysAsSent() throws {
    let document = try CommonsDiveSitePoints.decode(KitFixture.data("commons-dive-site-points"))
    #expect(document.version == "3f9a1c0b7e2d4a65")
    #expect(document.points.count == 2)
    #expect(document.points[1].source == "wikidata_sites")
    // The API's snake-case strategy would have read this key as `wikidataSites`.
    #expect(document.credit(document.points[1]) == "[Wikidata, CC0](https://www.wikidata.org/)")
  }

  @Test func aTripLookupRowCarriesItsPartsAndAKeptRowWithoutThemHasNone() throws {
    let trips = try KitFixture.decode(PaginatedListResponse<TripLookupItem>.self, "lookup-trips")
    let part = try #require(trips.data.first?.parts.first)
    #expect(part.startDate == CalendarDate(year: 2026, month: 9, day: 6))
    #expect(part.endDate == CalendarDate(year: 2026, month: 9, day: 20))
    #expect(part.location?.name == "Dahab, Egypt")

    let kept = #"{"uuid":"01a0a57a-92c3-73d0-8f2c-e200878f9878","name":"Red Sea","people":[]}"#
    let row = try APICoding.decoder().decode(TripLookupItem.self, from: Data(kept.utf8))
    #expect(row.parts.isEmpty)
  }
}
