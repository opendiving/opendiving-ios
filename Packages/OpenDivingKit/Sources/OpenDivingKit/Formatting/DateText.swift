import Foundation

/// Dates and times as the web prints them in `en-US`, built by hand rather than through a
/// `DateFormatter`: a formatter reads the device's locale for its month names and its
/// field order, and the device's zone for its clock. A day that is the phone's today or
/// yesterday reads `Today` or `Yesterday` instead, which the web does not do.
///
/// A dive's `start_time` prints in the dive's own offset, never the phone's — the
/// ``DiveTimestamp`` already holds the clock the diver saw, so nothing here converts it.
/// A naive value prints its clock with no zone, and a bare day prints the day alone.
/// A server timestamp (`created_at`, `last_used_at`) is an instant, and prints in the
/// zone it is given.
public enum DateText {
  // Each date takes `relativeTo`, the phone's day or the instant it is now: a date on that
  // day or the one before reads `Today` or `Yesterday`. Nil prints the date whatever it is.

  /// `Apr 4, 2021, 10:04` — a dive card's and a hero's facts line. A dive that carries
  /// only its day prints `Jun 18, 2002`: a midnight would be a time nobody recorded.
  public static func diveDateTime(
    _ start: DiveTimestamp, relativeTo today: CalendarDate? = .today()
  ) -> String {
    guard let clock = start.wallClock else { return date(start.calendarDate, relativeTo: today) }
    return date(clock.date, relativeTo: today) + ", " + time(clock)
  }

  /// `Apr 4, 2021`: the day the dive happened, on its own side of midnight — a species'
  /// last sighting, a neighbouring dive's label.
  public static func diveDate(_ start: DiveTimestamp, relativeTo today: CalendarDate? = .today())
    -> String
  {
    date(start.calendarDate, relativeTo: today)
  }

  /// `10:04`, on the dive's own clock. A bare day has no clock and reads `00:00`, as the
  /// web's does; a recording's `started_at`, the one caller, is never a bare day.
  public static func diveTime(_ start: DiveTimestamp) -> String {
    guard let clock = start.wallClock else { return "00:00" }
    return time(clock)
  }

  /// `Jun 1, 2024`: a date-only field — a card's `certified_on`, a site's last dive.
  public static func date(_ day: CalendarDate, relativeTo today: CalendarDate? = .today())
    -> String
  {
    today.flatMap { relativeDay(day, today: $0) } ?? monthAndDay(day) + ", " + String(day.year)
  }

  /// `Jun 1, 2024, 09:05`: a server timestamp, in `timeZone` — the phone's own unless a
  /// caller says otherwise — its day set against `now`'s in that zone.
  public static func dateTime(
    _ instant: Date, in timeZone: TimeZone = .current, relativeTo now: Date? = Date()
  ) -> String {
    let clock = localClock(instant, in: timeZone)
    return date(clock.date, relativeTo: today(now, in: timeZone)) + ", " + time(clock)
  }

  /// `Jun 1, 2024`: a server timestamp's day, in `timeZone`.
  public static func date(
    _ instant: Date, in timeZone: TimeZone = .current, relativeTo now: Date? = Date()
  ) -> String {
    date(localClock(instant, in: timeZone).date, relativeTo: today(now, in: timeZone))
  }

  /// A span of days, `Jun 1 - Jun 8, 2024`, with the start's year dropped when both fall
  /// in one year, and the one date alone when only one is set; nil when neither is.
  public static func dateRange(
    start: CalendarDate?, end: CalendarDate?, relativeTo today: CalendarDate? = .today()
  ) -> String? {
    switch (start, end) {
    case (nil, nil): return nil
    case (let start?, let end?):
      let startText =
        start.year == end.year && today.flatMap({ relativeDay(start, today: $0) }) == nil
        ? monthAndDay(start) : date(start, relativeTo: today)
      return startText + " - " + date(end, relativeTo: today)
    case (let only?, nil), (nil, let only?): return date(only, relativeTo: today)
    }
  }

  /// A date written after other words — *Queued today, 14:02* — with the `Today` or
  /// `Yesterday` it opens with lowercased; any other date is returned as it is.
  public static func inSentence(_ text: String) -> String {
    for word in relativeWords where text.hasPrefix(word) {
      return word.lowercased() + text.dropFirst(word.count)
    }
    return text
  }

  private static let relativeWords = ["Today", "Yesterday"]

  private static func relativeDay(_ day: CalendarDate, today: CalendarDate) -> String? {
    switch today.daysSinceEpoch - day.daysSinceEpoch {
    case 0: return relativeWords[0]
    case 1: return relativeWords[1]
    default: return nil
    }
  }

  private static func today(_ now: Date?, in timeZone: TimeZone) -> CalendarDate? {
    now.map { CalendarDate.today(in: timeZone, now: $0) }
  }

  /// A duration in seconds as `45min`, `1h 30min` or `2h`, to the nearest minute — a
  /// dive's *Dive time*.
  public static func hoursMinutes(seconds: Double) -> String {
    let totalMinutes = NumberText.round(seconds / 60)
    if totalMinutes < 60 { return NumberText.plain(totalMinutes) + "min" }
    let hours = (totalMinutes / 60).rounded(.down)
    let minutes = totalMinutes - hours * 60
    let hoursText = NumberText.plain(hours) + "h"
    return minutes > 0 ? hoursText + " " + NumberText.plain(minutes) + "min" : hoursText
  }

  /// ``hoursMinutes(seconds:)`` over whole seconds, `submerged_time`'s own unit.
  public static func hoursMinutes(seconds: Int) -> String {
    hoursMinutes(seconds: Double(seconds))
  }

  /// How long ago a day was, coarsening as it recedes: `today`, `yesterday`, `3 days ago`,
  /// `last week`, `4 months ago`, `2 years ago`. A day ahead reads as today.
  public static func daysAgo(_ days: Int) -> String {
    let ago = max(0, days)
    switch ago {
    case 0: return "today"
    case 1: return "yesterday"
    case ..<7: return "\(ago) days ago"
    case ..<30: return relative(ago / 7, "week")
    case ..<365: return relative(ago / 30, "month")
    default: return relative(ago / 365, "year")
    }
  }

  private static func relative(_ count: Int, _ unit: String) -> String {
    count == 1 ? "last " + unit : "\(count) \(unit)s ago"
  }

  static let shortMonths = [
    "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
  ]

  private static func monthAndDay(_ day: CalendarDate) -> String {
    shortMonths[day.month - 1] + " " + String(day.day)
  }

  /// Hours on a 24-hour clock from `00`, as `en-US` writes them with `hour12: false`.
  private static func time(_ clock: LocalDateTime) -> String {
    CalendarDate.pad(clock.hour, 2) + ":" + CalendarDate.pad(clock.minute, 2)
  }

  private static func localClock(_ instant: Date, in timeZone: TimeZone) -> LocalDateTime {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    let parts = calendar.dateComponents(
      [.year, .month, .day, .hour, .minute, .second], from: instant)
    // Every component is present for a Gregorian calendar asked for it.
    let day = CalendarDate(year: parts.year!, month: parts.month!, day: parts.day!)!
    return LocalDateTime(
      date: day, hour: parts.hour!, minute: parts.minute!, second: parts.second!)!
  }
}
