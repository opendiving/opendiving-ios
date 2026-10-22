import Foundation

/// When a dive started, in the one of three states the API can say it in. `start_time`
/// has four wire spellings and they land here as:
///
/// - `2021-04-04T10:04:00.5+02:00` and `2021-04-04T08:04:00Z` → ``instant(_:utcOffsetMinutes:)``
/// - `2021-04-04T10:04:00`, a dive whose zone was never recorded → ``wallClock(_:)``
/// - `2002-06-18`, a dive that carries only its day → ``day(_:)``
///
/// A naive reading is not an instant at offset zero, and a bare day is not midnight: either
/// collapse would print a time nobody recorded.
public enum DiveTimestamp: Hashable, Sendable {
  /// The clock the diver saw, and that clock's offset from UTC in minutes.
  case instant(LocalDateTime, utcOffsetMinutes: Int)
  /// The clock the diver saw, at an offset nobody recorded.
  case wallClock(LocalDateTime)
  /// The day alone.
  case day(CalendarDate)

  /// Parses any of the four spellings; nil for anything else.
  public init?(wireValue text: String) {
    var reader = WireReader(text)
    guard let date = reader.calendarDate() else { return nil }
    if reader.isAtEnd {
      self = .day(date)
      return
    }
    guard reader.consume("T"), let clock = reader.timeOfDay(on: date) else { return nil }
    if reader.isAtEnd {
      self = .wallClock(clock)
      return
    }
    guard let offset = reader.utcOffsetMinutes(), reader.isAtEnd else { return nil }
    self = .instant(clock, utcOffsetMinutes: offset)
  }

  /// The API's own spelling, which ``init(wireValue:)`` reads back to the same value.
  public var wireValue: String {
    switch self {
    case .instant(let clock, let offset):
      guard offset != 0 else { return clock.iso8601 + "Z" }
      let sign = offset < 0 ? "-" : "+"
      let minutes = abs(offset)
      return clock.iso8601 + sign + CalendarDate.pad(minutes / 60, 2) + ":"
        + CalendarDate.pad(minutes % 60, 2)
    case .wallClock(let clock):
      return clock.iso8601
    case .day(let date):
      return date.iso8601
    }
  }

  /// The day the diver's calendar showed, whichever state the timestamp is in.
  public var calendarDate: CalendarDate {
    switch self {
    case .instant(let clock, _), .wallClock(let clock): clock.date
    case .day(let date): date
    }
  }

  /// The clock the diver saw; nil for a bare day.
  public var wallClock: LocalDateTime? {
    switch self {
    case .instant(let clock, _), .wallClock(let clock): clock
    case .day: nil
    }
  }

  /// The offset from UTC in minutes; nil when nobody recorded one.
  public var utcOffsetMinutes: Int? {
    if case .instant(_, let offset) = self { offset } else { nil }
  }

  /// The moment itself; nil unless the offset is known.
  public var instant: Date? {
    guard case .instant(let clock, let offset) = self else { return nil }
    return Date(timeIntervalSince1970: clock.secondsSinceEpoch - Double(offset * 60))
  }
}

extension DiveTimestamp: Codable {
  public init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    let text = try container.decode(String.self)
    guard let timestamp = DiveTimestamp(wireValue: text) else {
      throw DecodingError.dataCorruptedError(
        in: container, debugDescription: "Not a dive start time: \"\(text)\"")
    }
    self = timestamp
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(wireValue)
  }
}
