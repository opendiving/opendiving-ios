import Foundation

/// A dive's start as the form picks it: a wall clock and the offset that clock kept.
public enum DiveStart {
  /// Every offset in use falls on fifteen minutes between UTC−12:00 and UTC+14:00, so the menu
  /// offers all of them rather than a hand-picked few.
  public static let offsets: [Int] = Array(stride(from: -12 * 60, through: 14 * 60, by: 15))

  /// The offset menu's choices. *Not recorded* — nil, first — only while the dive being edited
  /// has no offset: the API refuses to take one away, so it is offered nowhere else.
  public static func offsetChoices(editing dive: DiveReadWithMixtures? = nil) -> [Int?] {
    let unknown = dive.map { $0.startTime.utcOffsetMinutes == nil } ?? false
    return (unknown ? [nil] : []) + offsets.map(Optional.some)
  }

  /// `UTC+02:00`, `UTC-05:30`, `UTC+00:00`; *Not recorded* for nil.
  public static func offsetLabel(_ minutes: Int?) -> String {
    guard let minutes else { return "Not recorded" }
    return "UTC" + offsetText(minutes)
  }

  /// `+02:00`, `-05:45` (`formatUtcOffset`).
  static func offsetText(_ minutes: Int) -> String {
    let sign = minutes < 0 ? "-" : "+"
    let magnitude = abs(minutes)
    return sign + CalendarDate.pad(magnitude / 60, 2) + ":" + CalendarDate.pad(magnitude % 60, 2)
  }

  /// Now, to the second, on the phone's clock and with its offset: the start a new dive opens
  /// with, the best guess for a dive logged shortly after it was dived.
  public static func now(_ instant: Date = Date(), in timeZone: TimeZone = .current)
    -> DiveTimestamp
  {
    let offsetSeconds = timeZone.secondsFromGMT(for: instant)
    let wall = Int((instant.timeIntervalSince1970).rounded(.down)) + offsetSeconds
    let days = Int((Double(wall) / 86_400).rounded(.down))
    let secondOfDay = wall - days * 86_400
    let clock = LocalDateTime(
      date: CalendarDate(daysSinceEpoch: days), hour: secondOfDay / 3_600,
      minute: secondOfDay % 3_600 / 60, second: secondOfDay % 60)!
    return .instant(clock, utcOffsetMinutes: offsetSeconds / 60)
  }
}

extension CalendarDate {
  /// The day `days` after 1970-01-01 (Howard Hinnant's civil_from_days).
  init(daysSinceEpoch days: Int) {
    let z = days + 719_468
    let era = (z >= 0 ? z : z - 146_096) / 146_097
    let dayOfEra = z - era * 146_097
    let yearOfEra = (dayOfEra - dayOfEra / 1_460 + dayOfEra / 36_524 - dayOfEra / 146_096) / 365
    let dayOfYear = dayOfEra - (365 * yearOfEra + yearOfEra / 4 - yearOfEra / 100)
    let shiftedMonth = (5 * dayOfYear + 2) / 153
    let day = dayOfYear - (153 * shiftedMonth + 2) / 5 + 1
    let month = shiftedMonth < 10 ? shiftedMonth + 3 : shiftedMonth - 9
    let year = yearOfEra + era * 400 + (month <= 2 ? 1 : 0)
    self.init(year: year, month: month, day: day)!
  }
}
