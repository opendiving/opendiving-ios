/// A cursor over the ASCII of an ISO 8601 value, strict about the shapes the API writes:
/// `YYYY-MM-DD`, then optionally `THH:MM[:SS[.fraction]]`, then optionally `Z` or `±HH:MM`.
/// Hand-written rather than a date formatter, because no formatter keeps a naive value
/// naive or a bare day dateless, and Foundation's ISO 8601 parsing differs on Linux.
struct WireReader {
  private let bytes: [UInt8]
  private var index = 0

  init(_ text: String) {
    bytes = Array(text.utf8)
  }

  var isAtEnd: Bool { index == bytes.count }

  mutating func consume(_ character: Character) -> Bool {
    guard let ascii = character.asciiValue, index < bytes.count, bytes[index] == ascii else {
      return false
    }
    index += 1
    return true
  }

  mutating func calendarDate() -> CalendarDate? {
    guard let year = digits(4), consume("-"), let month = digits(2), consume("-"),
      let day = digits(2)
    else { return nil }
    return CalendarDate(year: year, month: month, day: day)
  }

  mutating func timeOfDay(on date: CalendarDate) -> LocalDateTime? {
    guard let hour = digits(2), consume(":"), let minute = digits(2) else { return nil }
    var second = 0
    var nanosecond = 0
    if consume(":") {
      guard let value = digits(2) else { return nil }
      second = value
      if consume(".") {
        guard let value = fractionNanoseconds() else { return nil }
        nanosecond = value
      }
    }
    return LocalDateTime(
      date: date, hour: hour, minute: minute, second: second, nanosecond: nanosecond)
  }

  /// `Z`, `±HH:MM` or `±HHMM`, as minutes east of UTC.
  mutating func utcOffsetMinutes() -> Int? {
    if consume("Z") { return 0 }
    let sign: Int
    if consume("+") {
      sign = 1
    } else if consume("-") {
      sign = -1
    } else {
      return nil
    }
    guard let hours = digits(2) else { return nil }
    _ = consume(":")
    guard let minutes = digits(2), hours <= 23, minutes <= 59 else { return nil }
    return sign * (hours * 60 + minutes)
  }

  private mutating func digits(_ count: Int) -> Int? {
    guard index + count <= bytes.count else { return nil }
    var value = 0
    for byte in bytes[index..<index + count] {
      guard let digit = Self.digit(byte) else { return nil }
      value = value * 10 + digit
    }
    index += count
    return value
  }

  /// One or more digits; anything past nanoseconds is dropped rather than rounded.
  private mutating func fractionNanoseconds() -> Int? {
    var value = 0
    var count = 0
    while index < bytes.count, let digit = Self.digit(bytes[index]) {
      if count < 9 { value = value * 10 + digit }
      count += 1
      index += 1
    }
    guard count > 0 else { return nil }
    for _ in count..<max(count, 9) { value *= 10 }
    return value
  }

  private static func digit(_ byte: UInt8) -> Int? {
    (48...57).contains(byte) ? Int(byte - 48) : nil
  }
}
