/// What the profile's head prints, as the web's Home hero does: the diver's name over the places
/// their trips went, when the logbook starts and was last added to, and its figures.
public enum ProfileSummary {
  /// `stats` and `places` are nil while unknown. Unknown figures print as dashes, since a zero
  /// would be a statement about the logbook; a logbook known to hold no dives has no dive
  /// figures, and a count known to be zero is left out. The world is drawn once the places are
  /// known, so the map does not move under their pins as they land.
  public static func hero(
    name: String, stats: UserDiveStatsRead?, places: [LocationRead]?, units: UnitSystem,
    today: CalendarDate
  ) -> HeroContent {
    HeroContent(
      title: name, facts: facts(stats, today: today), figures: figures(stats, places, units),
      points: (places ?? []).compactMap { LocationWrite($0).mapPoint },
      mapsTheWorldWhenEmpty: places != nil)
  }

  private static func facts(_ stats: UserDiveStatsRead?, today: CalendarDate) -> [Fact] {
    var facts: [Fact] = []
    if let first = stats?.firstDiveOn {
      facts.append(Fact(text: "Diving since \(first.year)"))
    }
    if let last = stats?.lastDiveOn {
      let days = today.daysSinceEpoch - last.daysSinceEpoch
      facts.append(Fact(text: "Last dive " + DateText.daysAgo(days)))
    }
    return facts
  }

  private static func figures(
    _ stats: UserDiveStatsRead?, _ places: [LocationRead]?, _ units: UnitSystem
  ) -> [Figure] {
    let dived = stats?.totalDives != 0
    var figures: [Figure] = []
    if dived {
      figures += [
        Figure(label: "Total dives", value: stats.map { String($0.totalDives) }),
        // Whole units and whole hours past the first: a career's totals, where the remainder
        // is noise.
        Figure(
          label: "Max depth", value: stats.map { UnitFormat.depth($0.maxDepth, units, decimals: 0) }
        ),
        Figure(label: "Total dive time", value: stats.map { diveTime($0.totalSubmergedTime) }),
      ]
    }
    if places?.isEmpty != true {
      figures.append(Figure(label: "Destinations", value: places.map { String($0.count) }))
    }
    if dived, stats?.diveSiteCount != 0 {
      figures.append(Figure(label: "Dive sites", value: stats.map { String($0.diveSiteCount) }))
    }
    if dived, stats?.speciesSeen != 0 {
      figures.append(Figure(label: "Species seen", value: stats.map { String($0.speciesSeen) }))
    }
    return figures
  }

  private static func diveTime(_ seconds: Int) -> String {
    guard seconds >= 3600 else { return DateText.hoursMinutes(seconds: seconds) }
    return NumberText.plain(NumberText.round(Double(seconds) / 3600)) + "h"
  }
}
