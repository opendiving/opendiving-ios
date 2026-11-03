import Foundation
import Testing

@testable import OpenDivingKit

/// What the Kit reads off the reader's dive: the start, as a wall clock or an instant by the
/// family, and whether it is a dive at all.
struct ComputerDiveTests {
  private func dive(_ json: String, logsInstants: Bool = false) -> ComputerDive? {
    ComputerDive(json: Data(json.utf8), logsInstants: logsInstants, fallbackStart: nil)
  }

  private let clock = LocalDateTime(
    date: CalendarDate(year: 2026, month: 10, day: 26)!, hour: 12, minute: 1, second: 49)!

  @Test func aWallClockKeepsTheZoneTheParserReported() {
    #expect(
      dive(#"{"started_at":"2026-10-26T12:01:49","recordings":[{}]}"#)?.start
        == .wallClock(clock, utcOffsetSeconds: nil))
    #expect(
      dive(#"{"started_at":"2026-10-26T12:01:49+03:00","recordings":[{}]}"#)?.start
        == .wallClock(clock, utcOffsetSeconds: 3 * 3600))
  }

  /// A Nautic start arrives at `+00:00` and is the moment the watch logged, for the writer to
  /// render in the diver's zone.
  @Test func aFamilyThatLogsInstantsReadsAnInstant() {
    #expect(
      dive(#"{"started_at":"2026-10-26T12:01:49+00:00","recordings":[{}]}"#, logsInstants: true)?
        .start == .instant(Date(timeIntervalSince1970: 1_793_016_109)))
  }

  @Test func onlyADiveWithAStartAndOneRecordingIsRead() {
    #expect(dive(#"{"recordings":[{}]}"#) == nil)
    #expect(dive(#"{"started_at":"2026-10-26","recordings":[{}]}"#) == nil)
    #expect(dive(#"{"started_at":"2026-10-26T12:01:49","recordings":[]}"#) == nil)
    #expect(dive(#"{"started_at":"2026-10-26T12:01:49","recordings":[{},{}]}"#) == nil)
    #expect(dive("[]") == nil)
  }

  /// No samples and at most a second's duration is no dive; either one makes it a dive.
  @Test func emptyIsNoProfileAndNoDuration() {
    let start = #""started_at":"2026-10-26T12:01:49""#
    #expect(dive("{\(start),\"recordings\":[{}]}")?.isEmpty == true)
    #expect(dive("{\(start),\"submerged_time\":1,\"recordings\":[{}]}")?.isEmpty == true)
    #expect(dive("{\(start),\"submerged_time\":2,\"recordings\":[{}]}")?.isEmpty == false)
    #expect(
      dive("{\(start),\"recordings\":[{\"profile\":{\"duration\":0}}]}")?.isEmpty == false)
  }

  @Test func aFallbackStartIsSpelledInUTC() {
    #expect(
      ComputerDive.instantText(Date(timeIntervalSince1970: 1_793_016_109))
        == "2026-10-26T12:01:49+00:00")
  }
}
