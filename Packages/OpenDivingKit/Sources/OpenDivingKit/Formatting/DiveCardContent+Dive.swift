extension DiveCardContent {
  /// The one mapping from a dive to its card, so that every list of dives draws the same
  /// card from the same fields.
  ///
  /// - The chips: the water type's and the dive type's abbreviations, labelled in full —
  ///   none for salt water, open circuit or a value without one — then the tags.
  /// - The facts: the start in the dive's own spelling, the first site's place, the boat
  ///   with its ship, and a paperclip when a recording is attached.
  /// - The figures: *Dive time*; *Max depth* at whole metres, a dash when unrecorded
  ///   and 0 m a reading; *Water temp* at whole degrees when recorded; and *Avg depth*
  ///   only while fewer than three figures show.
  /// - The outline: each depth as a fraction of the deepest, empty for a dive that never
  ///   left the surface.
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
    hasRecording: Bool,
    submergedSeconds: Int,
    maxDepth: Double?,
    avgDepth: Double?,
    waterTemperature: Double?,
    outline: [Int],
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
    chips += tags.map(Chip.tag)

    var facts = [Fact(text: DateText.diveDateTime(start))]
    if let locationName, !locationName.isEmpty { facts.append(Fact(text: locationName)) }
    if let boatName, !boatName.isEmpty {
      facts.append(Fact(text: boatName, systemImage: "ferry", accessibilityLabel: "Boat"))
    }
    if hasRecording {
      facts.append(Fact(systemImage: "paperclip", accessibilityLabel: "Recording attached"))
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
    if figures.count < 3, let avgDepth {
      figures.append(Figure(label: "Avg depth", value: depth(avgDepth)))
    }

    return DiveCardContent(
      title: DiveTitles.title(number: number, siteNames: siteNames),
      isCourse: isCourse,
      rating: rating,
      chips: chips,
      facts: facts,
      figures: figures,
      outline: normalizedOutline(outline))
  }

  /// Each depth as a fraction of the deepest, or nothing for a dive that never left the
  /// surface.
  static func normalizedOutline(_ depths: [Int]) -> [Double] {
    let deepest = max(0, depths.max() ?? 0)
    guard deepest > 0 else { return [] }
    return depths.map { Double($0) / Double(deepest) }
  }
}
