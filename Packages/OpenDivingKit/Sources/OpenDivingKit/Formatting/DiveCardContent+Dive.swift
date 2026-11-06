extension DiveCardContent {
  /// The one mapping from a dive to its card, so that every list of dives draws the same
  /// card from the same fields.
  ///
  /// - The chips: the water type's and the dive type's abbreviations, labelled in full —
  ///   none for salt water, open circuit or a value without one — then *Deco* for a dive
  ///   that owed decompression, then the tags.
  /// - The facts: the start in the dive's own spelling, the first site's place, the boat
  ///   with its ship, and a dive computer for each recording.
  /// - The figures: *Dive time*; *Max depth* at whole metres, a dash when unrecorded
  ///   and 0 m a reading; *Water temp* at whole degrees when recorded; and *Species seen*
  ///   only while fewer than three figures show.
  /// - The outline: each depth as a fraction of the deepest, empty for a dive that never
  ///   left the surface.
  /// - The map: its sites and fixes, as ``mapPlaces(sites:entry:exit:)`` has them.
  public static func dive(
    number: Int,
    siteNames: [String],
    isCourse: Bool,
    rating: Int?,
    waterType: String?,
    diveType: String?,
    tags: [String],
    start: DiveTimestamp,
    locationName: String?,
    boatName: String?,
    recordingCount: Int,
    owedDeco: Bool,
    submergedSeconds: Int,
    maxDepth: Double?,
    waterTemperature: Double?,
    speciesCount: Int,
    outline: [Int],
    places: (points: [MapPoint], fixes: [MapPoint]) = ([], []),
    units: UnitSystem
  ) -> DiveCardContent {
    var chips: [Chip] = []
    if let waterType, let text = VocabularyLabels.waterTypeAbbreviation(waterType) {
      chips.append(
        Chip(
          text: text, accessibilityLabel: VocabularyLabels.waterType(waterType),
          kind: .vocabulary))
    }
    if let diveType, let text = VocabularyLabels.diveTypeAbbreviation(diveType) {
      chips.append(
        Chip(
          text: text, accessibilityLabel: VocabularyLabels.diveType(diveType), kind: .vocabulary
        ))
    }
    if owedDeco {
      chips.append(Chip(text: "Deco", accessibilityLabel: "Decompression dive", kind: .vocabulary))
    }
    chips += tags.map(Chip.tag)

    var facts = [Fact(text: DateText.diveDateTime(start))]
    if let locationName, !locationName.isEmpty { facts.append(Fact(text: locationName)) }
    if let boatName, !boatName.isEmpty {
      facts.append(Fact(text: boatName, icon: .ship, accessibilityLabel: "Boat"))
    }
    if recordingCount > 0 {
      facts.append(
        Fact(
          icon: .diveComputer, iconCount: recordingCount,
          accessibilityLabel: recordingCount == 1
            ? "1 dive computer" : "\(recordingCount) dive computers"))
    }

    let depth = { (meters: Double?) in meters.map { UnitFormat.depth($0, units, decimals: 0) } }
    var figures = [
      Figure(label: "Dive time", value: DateText.hoursMinutes(seconds: submergedSeconds)),
      Figure(label: "Max depth", value: depth(maxDepth)),
    ]
    if let waterTemperature {
      figures.append(
        Figure(
          label: "Water temp", value: UnitFormat.temperature(waterTemperature, units, decimals: 0)
        ))
    }
    if figures.count < 3, speciesCount > 0 {
      figures.append(Figure(label: "Species seen", value: String(speciesCount)))
    }

    return DiveCardContent(
      title: DiveTitles.title(number: number, siteNames: siteNames),
      isCourse: isCourse,
      rating: rating,
      chips: chips,
      facts: facts,
      figures: figures,
      outline: normalizedOutline(outline),
      points: places.points,
      fixes: places.fixes)
  }

  /// Where a dive is on a map, as the web has it: its sites where they are pinned, and where
  /// the dive computer put the diver — a different claim, drawn apart. A fix at latitude or
  /// longitude 0 is a position, not an absence.
  public static func mapPlaces(
    sites: [DiveSiteInfo], entry: (Double?, Double?), exit: (Double?, Double?)
  ) -> (points: [MapPoint], fixes: [MapPoint]) {
    let points = sites.compactMap { site -> MapPoint? in
      guard let latitude = site.latitude, let longitude = site.longitude else { return nil }
      return MapPoint(name: site.name, latitude: latitude, longitude: longitude)
    }
    var fixes: [MapPoint] = []
    if case (let latitude?, let longitude?) = entry {
      fixes.append(MapPoint(name: "Entry", latitude: latitude, longitude: longitude))
    }
    if case (let latitude?, let longitude?) = exit {
      fixes.append(MapPoint(name: "Exit", latitude: latitude, longitude: longitude))
    }
    return (points, fixes)
  }

  /// Each depth as a fraction of the deepest, or nothing for a dive that never left the
  /// surface.
  static func normalizedOutline(_ depths: [Int]) -> [Double] {
    let deepest = max(0, depths.max() ?? 0)
    guard deepest > 0 else { return [] }
    return depths.map { Double($0) / Double(deepest) }
  }
}
