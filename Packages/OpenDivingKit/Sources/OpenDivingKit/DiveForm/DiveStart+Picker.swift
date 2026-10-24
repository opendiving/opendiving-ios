import Foundation

// A date picker works in instants and a zone; a dive's start is the clock the diver saw and that
// clock's offset. These carry one to the other without the phone's own zone in between, so a
// dive logged in Dahab and edited in Berlin keeps Dahab's clock.
extension DiveStart {
  /// The instant a picker shows for `start`, and the fixed zone that shows it as the dive's
  /// clock: the dive's offset, or UTC for a clock that records none — the clock is what the
  /// picker edits either way.
  public static func pickerValue(_ start: DiveTimestamp) -> (date: Date, timeZone: TimeZone) {
    let offset = start.utcOffsetMinutes ?? 0
    // Every offset the form offers is within the ±18 hours a fixed zone takes.
    let zone = TimeZone(secondsFromGMT: offset * 60)!
    let clock = start.wallClock
    let day = (clock?.date ?? start.calendarDate).daysSinceEpoch
    let seconds = (clock.map { $0.hour * 3_600 + $0.minute * 60 + $0.second }) ?? 0
    let wall = Double(day * 86_400 + seconds)
    return (Date(timeIntervalSince1970: wall - Double(offset * 60)), zone)
  }

  /// `start` moved to the clock `date` reads in `timeZone`, which ``pickerValue(_:)`` gave:
  /// the offset kept, a clock with none kept without one, a bare day kept a day.
  public static func picking(_ date: Date, in timeZone: TimeZone, keeping start: DiveTimestamp)
    -> DiveTimestamp
  {
    guard case .instant(let clock, _) = now(date, in: timeZone) else { return start }
    switch start {
    case .instant(_, let offset): return .instant(clock, utcOffsetMinutes: offset)
    case .wallClock: return .wallClock(clock)
    case .day: return .day(clock.date)
    }
  }

  /// `start` at another offset, its clock unchanged; nil takes the offset away, which only an
  /// edit of a dive that never had one offers. A bare day has no clock to offset.
  public static func withOffset(_ minutes: Int?, _ start: DiveTimestamp) -> DiveTimestamp {
    switch start {
    case .instant(let clock, _), .wallClock(let clock):
      minutes.map { .instant(clock, utcOffsetMinutes: $0) } ?? .wallClock(clock)
    case .day: start
    }
  }
}
