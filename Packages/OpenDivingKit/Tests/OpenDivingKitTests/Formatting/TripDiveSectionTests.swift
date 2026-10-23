import OpenDivingKit
import Testing

/// The web's own cases for grouping a trip's dives under its parts.
struct TripDiveSectionTests {
  private struct Dive: Equatable {
    let name: String
    let day: CalendarDate
  }

  private enum Shape: Equatable {
    case part(Int, [String])
    case loose([String])
  }

  private typealias Part = (start: CalendarDate?, end: CalendarDate?)

  private static func day(_ text: String) -> CalendarDate {
    CalendarDate(iso8601: text)!
  }

  private func dive(_ name: String, _ day: String) -> Dive {
    Dive(name: name, day: Self.day(day))
  }

  private func part(_ start: String?, _ end: String?) -> Part {
    (start: start.map(Self.day), end: end.map(Self.day))
  }

  private var dahab: Part { part("2026-04-03", "2026-04-08") }
  private var sharm: Part { part("2026-04-10", "2026-04-12") }
  private var nowhen: Part { part(nil, nil) }

  private func shape(_ dives: [Dive], _ parts: [Part], complete: Bool = true) -> [Shape] {
    TripDiveSection.sections(dives, parts: parts, complete: complete, day: \.day).map {
      switch $0 {
      case .part(let index, let items): .part(index, items.map(\.name))
      case .loose(let items): .loose(items.map(\.name))
      }
    }
  }

  @Test func eachDiveUnderThePartItsDayFallsInBetweenTheDivesNoneCovers() {
    let dives = [
      dive("after", "2026-04-14"), dive("sharm", "2026-04-12"), dive("gap-2", "2026-04-09"),
      dive("gap-1", "2026-04-09"), dive("dahab-2", "2026-04-08"), dive("dahab-1", "2026-04-03"),
    ]
    #expect(
      shape(dives, [dahab, sharm]) == [
        .loose(["after"]), .part(1, ["sharm"]), .loose(["gap-2", "gap-1"]),
        .part(0, ["dahab-2", "dahab-1"]),
      ])
  }

  @Test func readsTheDayAPartCoversFromTheDivesOwnCalendar() throws {
    // 00:30 on Apr 3 in Dahab is still Apr 2 in UTC.
    let start = try #require(DiveTimestamp(wireValue: "2026-04-03T00:30:00+02:00"))
    let sections = TripDiveSection.sections([start], parts: [dahab], day: \.calendarDate)
    #expect(sections == [.part(index: 0, items: [start])])
  }

  @Test func aPartWithOnlyAStartRunsOnAndOneWithOnlyAnEndRunsBack() {
    let dives = [dive("oct", "2026-10-03"), dive("sep", "2026-09-07"), dive("aug", "2026-08-18")]
    #expect(
      shape(dives, [nowhen, part("2026-09-01", nil)]) == [
        .part(1, ["oct", "sep"]), .part(0, []), .loose(["aug"]),
      ])
    #expect(
      shape(dives, [part(nil, "2026-09-07")]) == [.loose(["oct"]), .part(0, ["sep", "aug"])])
  }

  @Test func aDayTwoPartsCoverIsTheFirstsAndEachPartHasOneSection() {
    let dives = [
      dive("sharm", "2026-04-11"), dive("both", "2026-04-06"), dive("dahab", "2026-04-04"),
      dive("only-overlap", "2026-04-09"),
    ]
    #expect(
      shape(dives, [dahab, part("2026-04-05", "2026-04-11")]) == [
        .part(1, ["sharm", "only-overlap"]), .part(0, ["both", "dahab"]),
      ])
  }

  @Test func anEmptyPartSitsWhereItsLastDayFallsSplittingTheDivesAroundIt() {
    let empty = part("2026-04-12", "2026-04-13")
    let dives = [
      dive("after", "2026-04-15"), dive("gap-newer", "2026-04-14"),
      dive("gap-older", "2026-04-09"), dive("dahab", "2026-04-04"),
    ]
    #expect(
      shape(dives, [dahab, empty]) == [
        .loose(["after", "gap-newer"]), .part(1, []), .loose(["gap-older"]), .part(0, ["dahab"]),
      ])
    #expect(
      shape([dives[0], dives[3]], [dahab, empty]) == [
        .loose(["after"]), .part(1, []), .part(0, ["dahab"]),
      ])
  }

  @Test func aDatelessPartSitsJustAboveThePartItFollows() {
    let dives = [dive("sharm", "2026-04-11"), dive("dahab", "2026-04-04")]
    #expect(
      shape(dives, [dahab, nowhen, sharm]) == [
        .part(2, ["sharm"]), .part(1, []), .part(0, ["dahab"]),
      ])
    // Leading the trip, it goes below the part it precedes.
    #expect(
      shape(dives, [nowhen, dahab, sharm]) == [
        .part(2, ["sharm"]), .part(1, ["dahab"]), .part(0, []),
      ])
  }

  @Test func everyPartOfATripWithNoDivesNewestFirst() {
    #expect(shape([], [dahab, sharm]) == [.part(1, []), .part(0, [])])
  }

  @Test func leavesOutAnEmptyDatedPartTheLoadedPagesMayNotHaveReached() {
    let later = part("2026-04-14", "2026-04-15")
    let toEnd = part(nil, "2026-04-01")
    let parts = [toEnd, dahab, sharm, later, nowhen]
    let loaded = [dive("sharm", "2026-04-11")]
    #expect(
      shape(loaded, parts, complete: false) == [.part(4, []), .part(3, []), .part(2, ["sharm"])])
    // A part sharing the oldest loaded day waits too.
    #expect(
      shape([dive("dahab", "2026-04-03")], [dahab, sharm], complete: false) == [
        .part(1, []), .part(0, ["dahab"]),
      ])
    #expect(
      shape(loaded, parts) == [
        .part(4, []), .part(3, []), .part(2, ["sharm"]), .part(1, []), .part(0, []),
      ])
  }
}
