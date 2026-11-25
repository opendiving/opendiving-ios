import Foundation

/// What the renumber sheet opens on.
public struct RenumberDefaults: Hashable, Sendable {
  public let startAt: Int
  /// The first day in scope; nil reaches the whole log.
  public let fromDate: CalendarDate?

  public init(startAt: Int, fromDate: CalendarDate?) {
    self.startAt = startAt
    self.fromDate = fromDate
  }

  /// The card above the dives' renumber: the whole log, from #1.
  public static let wholeLog = RenumberDefaults(startAt: 1, fromDate: nil)
}

/// An import result's offer to renumber, made only where the import brought dives in and left
/// more dives sharing a number, or out of date order, than the log had before it. The sheet opens
/// on the part of the log the import reached, continuing from the dive before it, so a log that
/// continues a paper logbook at #47 is not offered a restart at #1. An offer rather than a step of
/// the import: the sheet stays the only thing that rewrites a number.
public struct RenumberSuggestion: Hashable, Sendable {
  public let text: String
  public let defaults: RenumberDefaults

  public init(text: String, defaults: RenumberDefaults) {
    self.text = text
    self.defaults = defaults
  }

  /// The offer after `read` applied; nil where there is none, and where a read fails — the card
  /// above the dives offers the renumber all the same.
  static func read(
    after read: LogbookImportRead, client: APIClient,
    offsetMinutes: Int = RenumberScope.phoneOffsetMinutes()
  ) async -> RenumberSuggestion? {
    guard let scope = RenumberScope.imported(read.dives, offsetMinutes: offsetMinutes),
      let after = try? await client.diveNumbering(),
      after.duplicateCount > read.numbering.duplicateCount
        || after.outOfDateOrderCount > read.numbering.outOfDateOrderCount,
      let description = DiveNumberingText.description(after),
      let next = try? await client.nextDiveNumber(startTime: scope.lastInstantBefore)
    else { return nil }
    return RenumberSuggestion(
      text: DiveNumberingText.importOffer(description, from: scope.day),
      defaults: RenumberDefaults(startAt: next.diveNumber, fromDate: scope.day))
  }
}

/// Days as a renumber's scope reads them. The API compares instants, so a day stands for the
/// instant it begins at the phone's offset now — the offset an import's offer reads its day at
/// too, so the scope it opens always reaches the earliest dive the import brought.
public enum RenumberScope {
  /// The phone's offset from UTC, in minutes.
  public static func phoneOffsetMinutes(_ zone: TimeZone = .current, now: Date = Date()) -> Int {
    zone.secondsFromGMT(for: now) / 60
  }

  /// The instant `day` begins at `offsetMinutes`.
  static func start(of day: CalendarDate, offsetMinutes: Int) -> DiveTimestamp {
    .instant(LocalDateTime(date: day, hour: 0, minute: 0)!, utcOffsetMinutes: offsetMinutes)
  }

  /// The day the earliest dive an import brought into the log began on, at `offsetMinutes`, and
  /// the last second before that day, whose next number the renumber starts at; nil where the
  /// import brought none.
  static func imported(_ dives: [LogbookImportDive], offsetMinutes: Int)
    -> (day: CalendarDate, lastInstantBefore: DiveTimestamp)?
  {
    let earliest = dives.filter { $0.outcome == "new" }.compactMap(\.startTime)
      .map(orderedAt).min()
    guard let earliest else { return nil }
    let shifted = earliest + Double(offsetMinutes * 60)
    let day = CalendarDate(daysSinceEpoch: Int((shifted / 86_400).rounded(.down)))
    let before = CalendarDate(daysSinceEpoch: day.daysSinceEpoch - 1)
    return (
      day,
      .instant(
        LocalDateTime(date: before, hour: 23, minute: 59, second: 59)!,
        utcOffsetMinutes: offsetMinutes)
    )
  }

  /// Where the API places a dive among the others, in seconds since 1970: the instant it names,
  /// its clock read as UTC where it carries no offset, the start of its day where it is a bare
  /// date.
  static func orderedAt(_ start: DiveTimestamp) -> Double {
    switch start {
    case .instant(let clock, let offset): clock.secondsSinceEpoch - Double(offset * 60)
    case .wallClock(let clock): clock.secondsSinceEpoch
    case .day(let date): Double(date.daysSinceEpoch * 86_400)
    }
  }
}
