/// A day with no clock and no zone: a trip part's dates, a card's `certified_on`, a dive
/// that carries only its day. Never a `Date` at UTC midnight, which a zone west of UTC
/// prints as the day before.
public struct CalendarDate: Hashable, Comparable, Sendable {
  public let year: Int
  public let month: Int
  public let day: Int

  /// Nil when the three do not name a day of the proleptic Gregorian calendar.
  public init?(year: Int, month: Int, day: Int) {
    guard (1...12).contains(month),
      (1...CalendarDate.daysIn(month: month, year: year)).contains(day)
    else { return nil }
    self.year = year
    self.month = month
    self.day = day
  }

  /// Parses `YYYY-MM-DD` and nothing else.
  public init?(iso8601 text: String) {
    var reader = WireReader(text)
    guard let date = reader.calendarDate(), reader.isAtEnd else { return nil }
    self = date
  }

  /// `YYYY-MM-DD`, the API's spelling.
  public var iso8601: String {
    "\(Self.pad(year, 4))-\(Self.pad(month, 2))-\(Self.pad(day, 2))"
  }

  /// Days since 1970-01-01, negative before it.
  public var daysSinceEpoch: Int {
    // Howard Hinnant's days_from_civil.
    let y = month <= 2 ? year - 1 : year
    let era = (y >= 0 ? y : y - 399) / 400
    let yearOfEra = y - era * 400
    let shiftedMonth = month > 2 ? month - 3 : month + 9
    let dayOfYear = (153 * shiftedMonth + 2) / 5 + day - 1
    let dayOfEra = yearOfEra * 365 + yearOfEra / 4 - yearOfEra / 100 + dayOfYear
    return era * 146_097 + dayOfEra - 719_468
  }

  public static func < (lhs: CalendarDate, rhs: CalendarDate) -> Bool {
    (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
  }

  static func daysIn(month: Int, year: Int) -> Int {
    switch month {
    case 2:
      let leap = (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
      return leap ? 29 : 28
    case 4, 6, 9, 11: return 30
    default: return 31
    }
  }

  static func pad(_ value: Int, _ width: Int) -> String {
    let digits = String(abs(value))
    let padded = String(repeating: "0", count: max(0, width - digits.count)) + digits
    return value < 0 ? "-" + padded : padded
  }
}

extension CalendarDate: Codable {
  public init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    let text = try container.decode(String.self)
    guard let date = CalendarDate(iso8601: text) else {
      throw DecodingError.dataCorruptedError(
        in: container, debugDescription: "Expected a YYYY-MM-DD date, got \"\(text)\"")
    }
    self = date
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(iso8601)
  }
}
