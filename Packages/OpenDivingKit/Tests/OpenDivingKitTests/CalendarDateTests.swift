import Foundation
import OpenDivingKit
import Testing

struct CalendarDateTests {
  @Test func parsesAndPrintsTheAPISpelling() {
    let date = CalendarDate(iso8601: "2024-02-29")
    #expect(date == CalendarDate(year: 2024, month: 2, day: 29))
    #expect(date?.iso8601 == "2024-02-29")
  }

  @Test(arguments: ["2023-02-29", "1900-02-29", "2024-04-31", "2024-00-10", "2024-1-10"])
  func rejectsDaysThatDoNotExist(text: String) {
    #expect(CalendarDate(iso8601: text) == nil)
  }

  @Test func countsDaysFromTheEpoch() {
    #expect(CalendarDate(year: 1970, month: 1, day: 1)?.daysSinceEpoch == 0)
    #expect(CalendarDate(year: 2000, month: 3, day: 1)?.daysSinceEpoch == 11_017)
    #expect(CalendarDate(year: 1969, month: 12, day: 31)?.daysSinceEpoch == -1)
  }

  @Test func ordersByDay() {
    let earlier = CalendarDate(year: 2024, month: 1, day: 31)!
    let later = CalendarDate(year: 2024, month: 2, day: 1)!
    #expect(earlier < later)
  }

  @Test func roundTripsThroughJSONAsAString() throws {
    let json = Data(#"["2024-06-01"]"#.utf8)
    let decoded = try JSONDecoder().decode([CalendarDate].self, from: json)
    #expect(
      String(decoding: try JSONEncoder().encode(decoded), as: UTF8.self) == #"["2024-06-01"]"#)
  }
}
