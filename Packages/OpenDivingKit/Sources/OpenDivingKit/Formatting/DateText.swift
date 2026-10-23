import Foundation

/// Dates and times as the web prints them in `en-US`, built by hand rather than through a
/// `DateFormatter`: a formatter reads the device's locale for its month names and its
/// field order, and the device's zone for its clock.
///
/// A dive's `start_time` prints in the dive's own offset, never the phone's — the
/// ``DiveTimestamp`` already holds the clock the diver saw, so nothing here converts it.
/// A naive value prints its clock with no zone, and a bare day prints the day alone.
/// A server timestamp (`created_at`, `last_used_at`) is an instant, and prints in the
/// zone it is given.
public enum DateText {
  /// `Apr 4, 2021, 10:04` — a dive card's and a hero's facts line. A dive that carries
  /// only its day prints `Jun 18, 2002`: a midnight would be a time nobody recorded.
  public static func diveDateTime(_ start: DiveTimestamp) -> String {
    guard let clock = start.wallClock else { return date(start.calendarDate) }
    return date(clock.date) + ", " + time(clock)
  }

  /// `Apr 4, 2021`: the day the dive happened, on its own side of midnight — a species'
  /// last sighting, a neighbouring dive's label.
  public static func diveDate(_ start: DiveTimestamp) -> String {
    date(start.calendarDate)
  }

  /// `10:04`, on the dive's own clock. A bare day has no clock and reads `00:00`, as the
  /// web's does; a recording's `started_at`, the one caller, is never a bare day.
  public static func diveTime(_ start: DiveTimestamp) -> String {
    guard let clock = start.wallClock else { return "00:00" }
    return time(clock)
  }

  /// `Jun 1, 2024`: a date-only field — a card's `certified_on`, a site's last dive.
  public static func date(_ day: CalendarDate) -> String {
    monthAndDay(day) + ", " + String(day.year)
  }

  /// `Jun 1, 2024, 09:05`: a server timestamp, in `timeZone` — the phone's own unless a
  /// caller says otherwise.
  public static func dateTime(_ instant: Date, in timeZone: TimeZone = .current) -> String {
    let clock = localClock(instant, in: timeZone)
    return date(clock.date) + ", " + time(clock)
  }

  /// `Jun 1, 2024`: a server timestamp's day, in `timeZone`.
  public static func date(_ instant: Date, in timeZone: TimeZone = .current) -> String {
    date(localClock(instant, in: timeZone).date)
  }

  /// A span of days, `Jun 1 - Jun 8, 2024`, with the start's year dropped when both fall
  /// in one year, and the one date alone when only one is set; nil when neither is.
  public static func dateRange(start: CalendarDate?, end: CalendarDate?) -> String? {
    switch (start, end) {
    case (nil, nil): return nil
    case (let start?, let end?):
      let startText = start.year == end.year ? monthAndDay(start) : date(start)
      return startText + " - " + date(end)
    case (let only?, nil), (nil, let only?): return date(only)
    }
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
