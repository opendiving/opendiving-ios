import Foundation
import Testing

@testable import OpenDivingKit

/// Each host's opening rule, one step at a time, each with exactly the data that step reads.
struct SiteFinderOpeningTests {
  private let today = CalendarDate(year: 2026, month: 9, day: 10)!
  private let here = DeviceLocation(latitude: 12.34, longitude: 56.78)
  private let dahab = LocationRead(
    name: "Dahab, Egypt", latitude: 28.49, longitude: 34.51, bboxSouth: 28.33, bboxNorth: 28.65,
    bboxWest: 34.35, bboxEast: 34.67)

  /// The trip, its part from the 6th of September, through the 20th where `ends`.
  private func trips(ends: Bool = true) throws -> [TripRead] {
    var text = try KitFixture.text("trip")
    if ends {
      text = text.replacingOccurrences(of: #""end_date": null"#, with: #""end_date": "2026-09-20""#)
    }
    return [try APICoding.decoder().decode(TripRead.self, from: Data(text.utf8))]
  }

  /// The dive list's first page: its dive with its entry fix, or with none and one pinned site.
  private func lastDive(entry: Bool) throws -> [DiveListItem] {
    var text = try KitFixture.text("dives-page")
    if !entry {
      text = text.replacingOccurrences(
        of: #""entry_latitude": [-0-9.]+"#, with: #""entry_latitude": null"#,
        options: .regularExpression
      ).replacingOccurrences(
        of: #""dive_sites": []"#,
        with: #""dive_sites": [{"uuid":"01a14b2e-0c3d-7a10-9f00-4a2b3c4d5e6f","name":"Canyon","#
          + #""location":null,"latitude":28.5687,"longitude":34.5372}]"#)
    }
    return try APICoding.decoder().decode(
      PaginatedListResponse<DiveListItem>.self, from: Data(text.utf8)
    ).data
  }

  @Test func theSitesMapOpensOnThePhonesLocationFirst() throws {
    let opened = SiteFinderOpening.sitesMap(
      location: here, trips: try trips(), dives: try lastDive(entry: true), today: today)
    #expect(opened.points.map(\.latitude) == [12.34])
    #expect(opened.camera(width: 400, height: 300).zoom == SiteFinderOpening.pointZoom)
  }

  @Test func theSitesMapOpensOnATripPartHoldingToday() throws {
    let opened = SiteFinderOpening.sitesMap(
      location: nil, trips: try trips(), dives: try lastDive(entry: true), today: today)
    #expect(opened.points.first?.name == "Dahab, Egypt")
    #expect(opened.points.first?.bounds != nil)
  }

  @Test func aPartWithOnlyAStartHoldsThatDayAlone() throws {
    let opened = SiteFinderOpening.sitesMap(
      location: nil, trips: try trips(ends: false), dives: [],
      today: CalendarDate(year: 2026, month: 9, day: 6)!)
    #expect(opened.points.first?.name == "Dahab, Egypt")
    let later = SiteFinderOpening.sitesMap(
      location: nil, trips: try trips(ends: false), dives: [],
      today: CalendarDate(year: 2026, month: 9, day: 7)!)
    #expect(later.isWorld)
  }

  @Test func theSitesMapOpensOnTheLastDivesFixThenItsFirstSitesPin() throws {
    let past = CalendarDate(year: 2020, month: 1, day: 1)!
    let fixed = SiteFinderOpening.sitesMap(
      location: nil, trips: try trips(), dives: try lastDive(entry: true), today: past)
    #expect(fixed.points.map(\.latitude) == [28.420546])
    let pinned = SiteFinderOpening.sitesMap(
      location: nil, trips: [], dives: try lastDive(entry: false), today: past)
    #expect(pinned.points.map(\.latitude) == [28.5687])
    #expect(pinned.points.first?.name == "Canyon")
  }

  @Test func theSitesMapOpensOnTheWorldWithNothing() {
    let opened = SiteFinderOpening.sitesMap(location: nil, trips: [], dives: [], today: today)
    #expect(opened.isWorld)
    #expect(opened.camera(width: 400, height: 300) == .world)
  }

  @Test func theDiveFormFitsItsPinnedSitesFirst() {
    let sites = [
      MapPoint(name: "North", latitude: 28.6, longitude: 34.5),
      MapPoint(name: "South", latitude: 28.4, longitude: 34.5),
    ]
    let facts = SiteFinderOpening.DiveFormFacts(sites: sites, fix: here, start: today)
    #expect(!facts.needsLocation)
    let opened = SiteFinderOpening.diveForm(facts, location: here)
    #expect(opened.points == sites)
    let camera = opened.camera(width: 400, height: 300)
    #expect(abs(camera.latitude - 28.5) < 0.01)
    // Measured or not, the camera is over the middle of the sites.
    #expect(abs(opened.camera(width: 0, height: 0).latitude - camera.latitude) < 1e-9)
  }

  @Test func theDiveFormOpensOnItsFixThenTheLocationThenTheTripPart() {
    let fix = DeviceLocation(latitude: 27.9, longitude: 34.3)
    let parts = [TripLookupPart(startDate: today, endDate: today, location: dahab)]
    #expect(
      SiteFinderOpening.diveForm(.init(fix: fix, parts: parts, start: today), location: here)
        .points.map(\.latitude) == [27.9])
    let unfixed = SiteFinderOpening.DiveFormFacts(parts: parts, start: today)
    #expect(unfixed.needsLocation)
    #expect(SiteFinderOpening.diveForm(unfixed, location: here).points.map(\.latitude) == [12.34])
    #expect(SiteFinderOpening.diveForm(unfixed, location: nil).points.first?.name == "Dahab, Egypt")
  }

  @Test func theDiveFormOpensOnTheWorldWhenNoPartHoldsTheStart() {
    let parts = [
      TripLookupPart(
        startDate: CalendarDate(year: 2026, month: 1, day: 1), endDate: nil, location: dahab)
    ]
    #expect(
      SiteFinderOpening.diveForm(.init(parts: parts, start: today), location: nil).isWorld)
    #expect(SiteFinderOpening.diveForm(.init(parts: parts), location: nil).isWorld)
  }
}
