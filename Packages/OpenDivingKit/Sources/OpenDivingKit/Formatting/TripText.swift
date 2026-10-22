/// What a trip's parts add up to on screen: the span of days, the places, and which part
/// a dive belongs to. Each part is its two optional dates, and its place's name where
/// it has one, in the diver's order.
public enum TripText {
  /// What separates one place from the next: a place's own name carries its country
  /// ("Dahab, Egypt"), so a comma would run two places into one list.
  static let placeSeparator = "; "
  /// How many places a trip's card, hero and a dive's Location card show before the
  /// rest become `+N`.
  public static let shownLocations = 1

  /// The trip's span — the earliest start and the latest end across its parts, each
  /// taken on its own — as `Apr 18 - Apr 25, 2026`; nil when no part carries a date.
  public static func span(_ parts: [(start: CalendarDate?, end: CalendarDate?)]) -> String? {
    let start = parts.compactMap(\.start).min()
    let end = parts.compactMap(\.end).max()
    return DateText.dateRange(start: start, end: end)
  }

  /// One part's dates on the trip's page: a range, `From Sep 1, 2026` or `Until Apr 6,
  /// 2021` for a part with one date, nil for a part with none.
  public static func partDates(start: CalendarDate?, end: CalendarDate?) -> String? {
    switch (start, end) {
    case (let start?, nil): "From " + DateText.date(start)
    case (nil, let end?): "Until " + DateText.date(end)
    default: DateText.dateRange(start: start, end: end)
    }
  }

  /// The places as `Dahab, Egypt; Bohol +2`, at most `max` of them named, or nil when
  /// none has a name. A part with no place, or a blank name, is skipped rather than
  /// joined around.
  public static func locationNames(_ names: [String?], max: Int? = nil) -> String? {
    let usable = names.compactMap { $0?.trimmedOfWhitespace }.filter { !$0.isEmpty }
    guard !usable.isEmpty else { return nil }
    let limit = max.flatMap { $0 > 0 ? $0 : nil } ?? usable.count
    let shown = usable.prefix(limit).joined(separator: placeSeparator)
    let hidden = usable.count - min(limit, usable.count)
    return hidden > 0 ? "\(shown) +\(hidden)" : shown
  }

  /// The trip's places as its card, its hero and a dive's Location card print them:
  /// ``locationNames(_:max:)`` with ``shownLocations`` named.
  public static func locationsLabel(_ names: [String?]) -> String? {
    locationNames(names, max: shownLocations)
  }

  /// The index of the part a day falls in, or nil when none does.
  ///
  /// A part with both dates covers the days between them and beats any part with one. A
  /// part with only a start runs on from it and one with only an end runs back to it;
  /// where two such parts reach a day, the one whose date is nearer has it. A part with
  /// no dates covers no day, and ties go to the first part.
  ///
  /// The same rule is held by the web, which groups a trip's dives with it, and by the
  /// API, which counts each part's candidate dives with it; a change to it is owed in
  /// all three.
  public static func partForDay(
    _ parts: [(start: CalendarDate?, end: CalendarDate?)], day: CalendarDate
  ) -> Int? {
    var best: Int?
    var bestDistance = Int.max
    for (index, part) in parts.enumerated() {
      let distance: Int
      switch (part.start, part.end) {
      case (let start?, let end?):
        guard start <= day, day <= end else { continue }
        distance = -1
      case (let start?, nil):
        guard start <= day else { continue }
        distance = day.daysSinceEpoch - start.daysSinceEpoch
      case (nil, let end?):
        guard day <= end else { continue }
        distance = end.daysSinceEpoch - day.daysSinceEpoch
      case (nil, nil):
        continue
      }
      if distance < bestDistance {
        best = index
        bestDistance = distance
      }
    }
    return best
  }
}
