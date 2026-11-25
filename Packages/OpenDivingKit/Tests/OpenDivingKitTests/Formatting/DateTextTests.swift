import Foundation
import OpenDivingKit
import Testing

/// Each expected string is the web's, from the test named beside it at `opendiving-web`
/// `ec014ff9`.
struct DateTextTests {
  private func start(_ wire: String) -> DiveTimestamp {
    DiveTimestamp(wireValue: wire)!
  }

  private func day(_ wire: String) -> CalendarDate {
    CalendarDate(iso8601: wire)!
  }

  // MARK: The four spellings of `start_time`

  /// `import-page-content.render.test.tsx:606`: a naive start reads its own clock, no zone.
  @Test func naiveStartReadsItsWallClock() {
    #expect(DateText.diveDateTime(start("2026-09-21T10:47:33")) == "Sep 21, 2026, 10:47")
  }

  /// `date-time.test.ts:304`, and `import-page-content.render.test.tsx:606`: a bare day
  /// prints the day and no midnight.
  @Test func bareDateReadsItsDayAlone() {
    #expect(DateText.diveDateTime(start("2002-06-18")) == "Jun 18, 2002")
    #expect(DateText.diveDate(start("2002-06-18")) == "Jun 18, 2002")
  }

  /// `date-time.test.ts:340` and `:351`: an offset-aware start reads at its own offset,
  /// on its own side of midnight.
  @Test func offsetAwareStartReadsAtItsOwnOffset() {
    #expect(DateText.diveTime(start("2021-04-04T10:04:47+02:00")) == "10:04")
    #expect(DateText.diveDate(start("2021-04-04T23:30:00+02:00")) == "Apr 4, 2021")
    #expect(DateText.diveDateTime(start("2021-04-04T23:30:00-05:00")) == "Apr 4, 2021, 23:30")
  }

  /// `species.test.ts:128`: late on the 30th at +07:00 is the 29th in UTC.
  @Test func sightingDayIsTheDivesOwn() {
    #expect(DateText.diveDate(start("2026-08-30T02:00:00+07:00")) == "Aug 30, 2026")
  }

  @Test func zuluReadsAtUTC() {
    #expect(DateText.diveDateTime(start("2021-04-04T08:04:00Z")) == "Apr 4, 2021, 08:04")
  }

  // MARK: Date-only fields and server timestamps

  /// `date-time.test.ts:42`, `:56`, `:57`.
  @Test(
    arguments: [
      ("2024-06-01", "Jun 1, 2024"), ("2024-01-01", "Jan 1, 2024"), ("2024-12-31", "Dec 31, 2024"),
    ] as [(String, String)])
  func dateOnlyNeverShifts(wire: String, expected: String) {
    #expect(DateText.date(day(wire)) == expected)
  }

  /// `date-time.test.ts:63`: a server timestamp, read in the zone it is shown in.
  @Test func serverTimestampReadsInTheGivenZone() {
    let instant = Date(timeIntervalSince1970: 1_717_232_700)  // 2024-06-01T09:05:00Z
    #expect(DateText.dateTime(instant, in: TimeZone(identifier: "UTC")!) == "Jun 1, 2024, 09:05")
    #expect(
      DateText.dateTime(instant, in: TimeZone(identifier: "America/Los_Angeles")!)
        == "Jun 1, 2024, 02:05")
    #expect(
      DateText.date(instant, in: TimeZone(identifier: "Pacific/Kiritimati")!) == "Jun 1, 2024")
  }

  // MARK: Ranges and durations

  /// `date-time.test.ts:466-486`.
  @Test func dateRanges() {
    #expect(DateText.dateRange(start: nil, end: nil) == nil)
    #expect(
      DateText.dateRange(start: day("2024-06-01"), end: day("2024-06-08")) == "Jun 1 - Jun 8, 2024")
    #expect(
      DateText.dateRange(start: day("2024-12-30"), end: day("2025-01-02"))
        == "Dec 30, 2024 - Jan 2, 2025")
    #expect(DateText.dateRange(start: day("2024-06-01"), end: nil) == "Jun 1, 2024")
    #expect(DateText.dateRange(start: nil, end: day("2024-06-08")) == "Jun 8, 2024")
  }

  // MARK: Today and yesterday, which the web does not say

  @Test func theDaysAroundTodayReadAsWords() {
    let today = day("2026-11-18")
    #expect(DateText.date(day("2026-11-18"), relativeTo: today) == "Today")
    #expect(DateText.date(day("2026-11-17"), relativeTo: today) == "Yesterday")
    #expect(DateText.date(day("2026-11-16"), relativeTo: today) == "Nov 16, 2026")
    #expect(DateText.date(day("2026-11-19"), relativeTo: today) == "Nov 19, 2026")
    #expect(DateText.date(day("2026-12-31"), relativeTo: day("2027-01-01")) == "Yesterday")
    #expect(DateText.date(day("2026-11-18"), relativeTo: nil) == "Nov 18, 2026")
  }

  @Test func aDivesDayIsSetAgainstThePhonesToday() {
    let today = day("2026-11-18")
    #expect(
      DateText.diveDateTime(start("2026-11-18T10:04:00+02:00"), relativeTo: today)
        == "Today, 10:04")
    #expect(DateText.diveDateTime(start("2026-11-17"), relativeTo: today) == "Yesterday")
    #expect(DateText.diveDate(start("2026-11-17T23:30:00-05:00"), relativeTo: today) == "Yesterday")
  }

  @Test func aServerTimestampsDayIsSetAgainstNowInTheSameZone() {
    let instant = Date(timeIntervalSince1970: 1_794_895_200)  // 2026-11-17T06:00:00Z
    let now = Date(timeIntervalSince1970: 1_794_952_800)  // 2026-11-17T22:00:00Z
    let utc = TimeZone(identifier: "UTC")!
    let kiritimati = TimeZone(identifier: "Pacific/Kiritimati")!  // UTC+14
    #expect(DateText.dateTime(instant, in: utc, relativeTo: now) == "Today, 06:00")
    #expect(DateText.dateTime(instant, in: kiritimati, relativeTo: now) == "Yesterday, 20:00")
    #expect(DateText.date(instant, in: utc, relativeTo: now) == "Today")
    #expect(DateText.dateTime(instant, in: utc, relativeTo: nil) == "Nov 17, 2026, 06:00")
  }

  @Test func aRangeSaysTodayAtEitherEnd() {
    let today = day("2026-11-18")
    #expect(
      DateText.dateRange(start: day("2026-11-10"), end: day("2026-11-18"), relativeTo: today)
        == "Nov 10 - Today")
    #expect(
      DateText.dateRange(start: day("2026-11-17"), end: day("2026-11-25"), relativeTo: today)
        == "Yesterday - Nov 25, 2026")
    #expect(
      DateText.dateRange(start: day("2026-11-18"), end: nil, relativeTo: today) == "Today")
  }

  @Test func inASentenceTheWordIsLowercased() {
    #expect(DateText.inSentence("Today, 10:04") == "today, 10:04")
    #expect(DateText.inSentence("Yesterday") == "yesterday")
    #expect(DateText.inSentence("Nov 16, 2026") == "Nov 16, 2026")
  }

  @Test(
    arguments: [
      (2700, "45min"), (5400, "90min"), (7200, "120min"), (59.6 * 60, "60min"), (0, "0min"),
    ]
      as [(Double, String)])
  func minutesNeverTurnIntoHours(seconds: Double, expected: String) {
    #expect(DateText.minutes(seconds: seconds) == expected)
  }

  /// `date-time.test.ts:428-440`.
  @Test(
    arguments: [(2700, "45min"), (5400, "1h 30min"), (7200, "2h"), (59.6 * 60, "1h")]
      as [(Double, String)])
  func hoursAndMinutes(seconds: Double, expected: String) {
    #expect(DateText.hoursMinutes(seconds: seconds) == expected)
  }

  /// `date-time.test.ts:445-458`, at `c8f5fd32`.
  @Test(
    arguments: [
      (0, "today"), (1, "yesterday"), (3, "3 days ago"), (7, "last week"), (20, "2 weeks ago"),
      (45, "last month"), (200, "6 months ago"), (400, "last year"), (1100, "3 years ago"),
      (-2, "today"),
    ])
  func daysAgo(days: Int, expected: String) {
    #expect(DateText.daysAgo(days) == expected)
  }
}

/// The dive's own clock never passes through the phone's zone: the same strings under a
/// zone far from UTC either way (`date-time.test.ts:241-329`).
@Suite(.serialized)
struct DateTextTimeZoneTests {
  @Test(arguments: ["Pacific/Kiritimati", "Pacific/Pago_Pago", "America/Sao_Paulo"])
  func diveTimesIgnoreThePhonesZone(zone: String) {
    let saved = NSTimeZone.default
    NSTimeZone.default = TimeZone(identifier: zone)!
    defer { NSTimeZone.default = saved }

    #expect(
      DateText.diveDateTime(DiveTimestamp(wireValue: "2026-04-17T11:49:23")!)
        == "Apr 17, 2026, 11:49")
    #expect(DateText.diveTime(DiveTimestamp(wireValue: "2026-04-17T11:49:23")!) == "11:49")
    #expect(DateText.diveDateTime(DiveTimestamp(wireValue: "2002-06-18")!) == "Jun 18, 2002")
    #expect(
      DateText.diveDateTime(DiveTimestamp(wireValue: "2021-04-04T10:04:47+02:00")!)
        == "Apr 4, 2021, 10:04")
    #expect(DateText.date(CalendarDate(iso8601: "2024-06-01")!) == "Jun 1, 2024")
  }
}
