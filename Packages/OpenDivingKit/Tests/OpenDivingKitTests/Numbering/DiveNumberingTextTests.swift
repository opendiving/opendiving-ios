import Foundation
import Testing

@testable import OpenDivingKit

/// The numbering card's sentence, and the day an import's offer opens the sheet on.
struct DiveNumberingTextTests {
  private func summary(
    total: Int = 40, lowest: Int? = 1, highest: Int? = 40, missing: Int = 0, duplicates: Int = 0,
    outOfOrder: Int = 0
  ) -> DiveNumberingSummary {
    DiveNumberingSummary(
      totalDives: total, lowest: lowest, highest: highest, missingCount: missing,
      duplicateCount: duplicates, outOfDateOrderCount: outOfOrder,
      isSequential: missing == 0 && duplicates == 0)
  }

  @Test func aTidyLogOrAnEmptyOneSaysNothing() {
    #expect(DiveNumberingText.description(summary()) == nil)
    #expect(
      DiveNumberingText.description(summary(total: 0, lowest: nil, highest: nil)) == nil)
  }

  @Test func theSentenceSaysWhatARenumberWouldTidy() throws {
    let numbering = try KitFixture.roundTrip(DiveNumberingSummary.self, "dives-numbering")
    #expect(
      DiveNumberingText.description(numbering)
        == "Numbered #1–#215 — 5 numbers unused, 2 dives share a number, 1 out of date order.")
    #expect(
      DiveNumberingText.description(summary(missing: 1))
        == "Numbered #1–#40 — 1 number unused.")
  }

  @Test func divesSharingOneNumberReadAsThatNumber() {
    #expect(
      DiveNumberingText.description(summary(total: 2, lowest: 7, highest: 7, duplicates: 2))
        == "Numbered #7 — 2 dives share a number.")
  }

  @Test func aChangeReadsAsItsMove() throws {
    let result = try KitFixture.roundTrip(DiveRenumberResult.self, "dives-renumber")
    #expect(result.changes.map(DiveNumberingText.move) == ["#51 → #47", "#47 → #48"])
    #expect(DiveNumberingText.changeCount(result) == "2 of 3 dives would be renumbered.")
  }

  private func dive(_ outcome: String, _ start: String?) throws -> LogbookImportDive {
    let time = start.map { #""start_time":"\#($0)","# } ?? ""
    return try APICoding.decoder().decode(
      LogbookImportDive.self,
      from: Data(#"{\#(time)"outcome":"\#(outcome)","changes":[],"members":[]}"#.utf8))
  }

  @Test func anImportsScopeStartsOnItsEarliestNewDivesDayOnThePhonesCalendar() throws {
    let dives = [
      try dive("new", "2024-03-02T08:00:00+02:00"),
      // 16:30 UTC on the 1st, the earliest, though its own clock reads the 2nd.
      try dive("new", "2024-03-02T01:30:00+09:00"),
      try dive("unchanged", "2020-01-01T10:00:00+00:00"),
      try dive("new", nil),
    ]
    let atPlusThree = try #require(RenumberScope.imported(dives, offsetMinutes: 180))
    #expect(atPlusThree.day == CalendarDate(year: 2024, month: 3, day: 1))
    #expect(atPlusThree.lastInstantBefore.wireValue == "2024-02-29T23:59:59+03:00")

    // Fourteen hours east of UTC, 16:30 UTC on the 1st is already the 2nd.
    let atPlusFourteen = try #require(RenumberScope.imported(dives, offsetMinutes: 840))
    #expect(atPlusFourteen.day == CalendarDate(year: 2024, month: 3, day: 2))
    #expect(atPlusFourteen.lastInstantBefore.wireValue == "2024-03-01T23:59:59+14:00")
  }

  private func stamp(_ text: String) throws -> DiveTimestamp {
    try #require(DiveTimestamp(wireValue: text))
  }

  @Test func aDiveWithNoOffsetIsPlacedByItsClockAsUTCAndABareDayByItsStart() throws {
    #expect(
      RenumberScope.orderedAt(try stamp("2024-03-02T01:00:00"))
        == RenumberScope.orderedAt(try stamp("2024-03-02T01:00:00Z")))
    #expect(
      RenumberScope.orderedAt(try stamp("2024-03-02"))
        == RenumberScope.orderedAt(try stamp("2024-03-02T00:00:00Z")))
  }

  @Test func anImportThatBroughtNoDiveHasNoScope() throws {
    #expect(RenumberScope.imported([try dive("skipped", "2024-03-02")], offsetMinutes: 0) == nil)
  }

  @Test func aDayStartsAtMidnightAtTheOffsetGiven() throws {
    let day = try #require(CalendarDate(year: 2023, month: 1, day: 1))
    #expect(
      RenumberScope.start(of: day, offsetMinutes: 120).wireValue == "2023-01-01T00:00:00+02:00")
  }
}
