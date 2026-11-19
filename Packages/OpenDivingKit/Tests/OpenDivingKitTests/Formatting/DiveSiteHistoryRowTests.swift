import Foundation
import OpenDivingKit
import Testing

/// A Commons record's *History* rows, as the web's `SiteHistoryCard` prints them.
struct DiveSiteHistoryRowTests {
  private func rows(_ units: UnitSystem = .metric) throws -> [DiveSiteHistoryRow] {
    try KitFixture.decode(
      PaginatedListResponse<DiveSiteHistoryEntryRead>.self, "dive-site-history-page"
    ).data.map {
      DiveSiteHistoryRow(
        $0, units: units, in: TimeZone(identifier: "Asia/Tokyo")!, relativeTo: nil)
    }
  }

  private func lines(_ row: DiveSiteHistoryRow) -> [String: String] {
    Dictionary(uniqueKeysWithValues: row.details.map { ($0.label, $0.value) })
  }

  @Test func theDecodedPage() throws {
    let page = try KitFixture.roundTrip(
      PaginatedListResponse<DiveSiteHistoryEntryRead>.self, "dive-site-history-page")
    #expect(page.data.map(\.kind) == ["changed", "changed", "changed", "added"])
    #expect(page.data[2].madeBy == nil)
    #expect(page.data[1].details[0].new == .array([.string("Tiger"), .string("Nemr")]))
  }

  @Test func anEntryNamesWhoMadeItWhereOneIsShownAndTheDay() throws {
    let rows = try rows()
    #expect(
      rows.map(\.title) == [
        "Changed by Rita Reviewer", "Changed by Ann Diver", "Changed", "Added by Ann Diver",
      ])
    // Past midnight in the zone asked for, a day after the instant's UTC date.
    #expect(rows[0].date == "Nov 17, 2026")
    #expect(rows[3].date == "Nov 1, 2026")
  }

  @Test func anAddedEntryListsNoDetails() throws {
    #expect(try rows()[3].details.isEmpty)
  }

  @Test func eachMemberReadsInTheFormsWordsAndTheDiversUnits() throws {
    let row = try rows()[1]
    #expect(
      row.details.map(\.label) == [
        "Other names", "Pin", "Location", "Registries", "Depth from", "Depth to", "Water type",
        "Altitude", "Entry types",
      ])
    let values = lines(row)
    #expect(values["Other names"] == "Not recorded → Tiger, Nemr")
    #expect(values["Location"] == "Not recorded → Dahab")
    #expect(values["Registries"] == "Not recorded → Wikidata Q42")
    #expect(values["Depth from"] == "Not recorded → 5 m")
    #expect(values["Depth to"] == "30 m → 32.5 m")
    #expect(values["Water type"] == "Salt water → Fresh water")
    #expect(values["Altitude"] == "0 m → 12 m")
    #expect(values["Entry types"] == "Shore → Shore, Boat")
    #expect(lines(try rows()[0]) == ["Name": "Tiger Reef → Tiger Reef North"])
  }

  @Test func imperialUnitsReadInFeet() throws {
    let values = lines(try rows(.imperial)[1])
    #expect(values["Depth to"] == "98 ft → 107 ft")
    #expect(values["Pin"] == "Moved 328 ft")
  }

  @Test func aMovedPinIsOneLineSayingHowFar() throws {
    let row = try rows()[1]
    #expect(row.details.filter { $0.label == "Pin" }.count == 1)
    #expect(lines(row)["Pin"] == "Moved 100 m")
  }

  @Test func aPinWithNoSideToMeasureFromShowsItsFigures() throws {
    #expect(lines(try rows()[2])["Pin"] == "Not recorded → 28.5722, 34.5372")
  }

  @Test func aFieldThisBuildDoesNotKnowReadsUnderItsOwnNameAsSent() throws {
    #expect(lines(try rows()[2])["visibility"] == #"Not recorded → {"metres":20}"#)
  }
}
