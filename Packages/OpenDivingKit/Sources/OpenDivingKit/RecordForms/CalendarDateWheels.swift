/// What a day's wheels do for a field that may be one half of a start and end pair. A wheel cannot
/// shade a range as the web's calendar does, so the other half is named above it instead.
public struct CalendarDateWheels: Hashable, Sendable {
  /// The day they open on; nil for today. An empty half opens on the other half, which for a
  /// back-filled logbook is usually years from today.
  public let opensOn: CalendarDate?
  /// The first day they turn to: an end stops at its start.
  public let earliest: CalendarDate?
  /// The other half of the range.
  public let note: String?

  /// `rangeStart` for the end half of a pair, `rangeEnd` for the start half. An end already
  /// before its start opens on the start, the one day of the two the wheels can show.
  public init(
    held: CalendarDate?, rangeStart: CalendarDate? = nil, rangeEnd: CalendarDate? = nil
  ) {
    let day = held ?? rangeStart ?? rangeEnd
    opensOn = day.map { max($0, rangeStart ?? $0) }
    earliest = rangeStart
    note =
      rangeStart.map { "Starts \(DateText.date($0))" }
      ?? rangeEnd.map { "Ends \(DateText.date($0))" }
  }
}
