import Foundation
import OpenDivingKit
import Testing

struct DiveTimestampTests {
  private func clock(
    _ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int, _ second: Int = 0,
    nanosecond: Int = 0
  ) -> LocalDateTime {
    let date = CalendarDate(year: year, month: month, day: day)!
    return LocalDateTime(
      date: date, hour: hour, minute: minute, second: second, nanosecond: nanosecond)!
  }

  @Test func offsetAwareWithFractionIsAnInstantAtItsOffset() {
    let timestamp = DiveTimestamp(wireValue: "2021-04-04T10:04:00.123456+02:00")
    #expect(
      timestamp
        == .instant(clock(2021, 4, 4, 10, 4, nanosecond: 123_456_000), utcOffsetMinutes: 120))
    #expect(timestamp?.instant == Date(timeIntervalSince1970: 1_617_523_440.123456))
  }

  @Test func zuluIsAnInstantAtOffsetZero() {
    let timestamp = DiveTimestamp(wireValue: "2021-04-04T08:04:00Z")
    #expect(timestamp == .instant(clock(2021, 4, 4, 8, 4), utcOffsetMinutes: 0))
    #expect(timestamp?.instant == Date(timeIntervalSince1970: 1_617_523_440))
  }

  @Test func naiveIsAWallClockWithNoOffset() {
    let timestamp = DiveTimestamp(wireValue: "2019-11-02T11:49:00")
    #expect(timestamp == .wallClock(clock(2019, 11, 2, 11, 49)))
    #expect(timestamp?.utcOffsetMinutes == nil)
    #expect(timestamp?.instant == nil)
  }

  @Test func bareDateIsADayWithNoClock() {
    let timestamp = DiveTimestamp(wireValue: "2002-06-18")
    #expect(timestamp == .day(CalendarDate(year: 2002, month: 6, day: 18)!))
    #expect(timestamp?.wallClock == nil)
    #expect(timestamp?.calendarDate == CalendarDate(year: 2002, month: 6, day: 18))
  }

  @Test(arguments: [
    ("2021-04-04T10:04:00-03:30", -210),
    ("2021-04-04T10:04:00+05:45", 345),
    ("2021-04-04T10:04:00+0545", 345),
    ("2021-04-04T10:04:00+00:00", 0),
  ])
  func offsetsAreMinutesEastOfUTC(wire: String, minutes: Int) {
    #expect(DiveTimestamp(wireValue: wire)?.utcOffsetMinutes == minutes)
  }

  @Test(arguments: [
    "", "2021-04-04T", "2021-04-04 10:04:00", "2021-13-01", "2021-02-29", "2021-04-04T24:00:00",
    "2021-04-04T10:04:00.", "2021-04-04T10:04:00+2", "2021-04-04T10:04:00Zjunk", "21-04-04",
    "2021-04-04T10:04:60",
  ])
  func rejectsAnythingElse(wire: String) {
    #expect(DiveTimestamp(wireValue: wire) == nil)
  }

  @Test(arguments: [
    "2021-04-04T10:04:00.5+02:00", "2021-04-04T08:04:00Z", "2019-11-02T11:49:00",
    "2002-06-18", "1999-12-31T23:59:59.000000001-09:30",
  ])
  func wireValueReadsBackToTheSameTimestamp(wire: String) throws {
    let timestamp = try #require(DiveTimestamp(wireValue: wire))
    #expect(DiveTimestamp(wireValue: timestamp.wireValue) == timestamp)
  }

  @Test func decodesFromJSONAndEncodesTheWireSpelling() throws {
    let json = Data(#"["2021-04-04T10:04:00+02:00","2019-11-02T11:49:00","2002-06-18"]"#.utf8)
    let decoded = try JSONDecoder().decode([DiveTimestamp].self, from: json)
    #expect(decoded.map(\.calendarDate.day) == [4, 2, 18])
    let encoded = try JSONEncoder().encode(decoded)
    #expect(try JSONDecoder().decode([DiveTimestamp].self, from: encoded) == decoded)
  }

  @Test func decodingAnUnknownSpellingThrows() {
    #expect(throws: DecodingError.self) {
      try JSONDecoder().decode([DiveTimestamp].self, from: Data(#"["yesterday"]"#.utf8))
    }
  }
}
