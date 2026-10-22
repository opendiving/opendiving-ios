/// A wall-clock reading: a day and a time of day, with no zone attached. On its own it
/// says what a clock showed, not when that was.
public struct LocalDateTime: Hashable, Comparable, Sendable {
  public let date: CalendarDate
  public let hour: Int
  public let minute: Int
  public let second: Int
  public let nanosecond: Int

  /// Nil when a field is out of range. A leap second (`:60`) is not accepted.
  public init?(date: CalendarDate, hour: Int, minute: Int, second: Int = 0, nanosecond: Int = 0) {
    guard (0...23).contains(hour), (0...59).contains(minute), (0...59).contains(second),
      (0...999_999_999).contains(nanosecond)
    else { return nil }
    self.date = date
    self.hour = hour
    self.minute = minute
    self.second = second
    self.nanosecond = nanosecond
  }

  /// `YYYY-MM-DDTHH:MM:SS`, with the fraction when there is one, trimmed of trailing zeros.
  public var iso8601: String {
    var text =
      "\(date.iso8601)T\(CalendarDate.pad(hour, 2)):\(CalendarDate.pad(minute, 2)):"
      + CalendarDate.pad(second, 2)
    if nanosecond > 0 {
      var fraction = CalendarDate.pad(nanosecond, 9)
      while fraction.hasSuffix("0") { fraction.removeLast() }
      text += "." + fraction
    }
    return text
  }

  /// Seconds since 1970-01-01T00:00:00 on the same clock, as if the clock were UTC.
  var secondsSinceEpoch: Double {
    Double(date.daysSinceEpoch * 86_400 + hour * 3_600 + minute * 60 + second)
      + Double(nanosecond) / 1_000_000_000
  }

  public static func < (lhs: LocalDateTime, rhs: LocalDateTime) -> Bool {
    (lhs.date, lhs.hour, lhs.minute, lhs.second, lhs.nanosecond)
      < (rhs.date, rhs.hour, rhs.minute, rhs.second, rhs.nanosecond)
  }
}
