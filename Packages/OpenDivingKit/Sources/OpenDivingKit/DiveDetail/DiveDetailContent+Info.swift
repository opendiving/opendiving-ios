extension DiveDetailContent {
  /// The dive's own fields in the dive form's sections and order, one value each, at the
  /// precision the form takes. What links another record, and the tanks, are left to the
  /// page's cards.
  static func info(_ dive: DiveReadWithMixtures, units: UnitSystem) -> [RecordInfoSection] {
    func fact<Value>(
      _ label: String, _ value: Value?, _ text: (Value) -> String
    ) -> RecordInfoFact {
      RecordInfoFact(label: label, value: value.map(text))
    }
    let depth = { (meters: Double) in UnitFormat.depth(meters, units) }
    let temperature = { (celsius: Double) in UnitFormat.temperature(celsius, units) }

    return [
      RecordInfoSection(
        heading: DiveFormGroup.location.rawValue,
        facts: [
          fact("Entry type", dive.entryType, VocabularyLabels.entryType),
          RecordInfoFact(label: "Boat name", value: dive.boatName),
        ]),
      RecordInfoSection(
        heading: DiveFormGroup.diveInfo.rawValue,
        facts: [
          fact("Dive type", dive.type, VocabularyLabels.diveType),
          RecordInfoFact(label: "Start time", value: DateText.diveDateTime(dive.startTime)),
          RecordInfoFact(label: "Dive number", value: String(dive.diveNumber)),
          RecordInfoFact(
            label: "Dive time", value: DateText.hoursMinutes(seconds: dive.submergedTime)),
          fact("Maximum depth", dive.maxDepth, depth),
          fact("Average depth", dive.avgDepth, depth),
        ]),
      RecordInfoSection(
        heading: DiveFormGroup.environment.rawValue,
        facts: [
          fact("Bottom temperature", dive.bottomTemperature, temperature),
          fact("Visibility", dive.visibility) { UnitFormat.visibility(Double($0), units) },
          fact("Water type", dive.waterType, VocabularyLabels.waterType),
          fact("Altitude", dive.altitude) { UnitFormat.altitude(Double($0), units) },
          fact("Waves", dive.waves, VocabularyLabels.waves),
          fact("Current", dive.current, VocabularyLabels.current),
          fact("Weather", dive.weather, VocabularyLabels.weather),
          fact("Air temperature", dive.airTemperature, temperature),
        ]),
      RecordInfoSection(
        heading: DiveFormGroup.gear.rawValue,
        facts: [fact("Weight", dive.weight) { UnitFormat.weight($0, units) }]),
      RecordInfoSection(
        heading: DiveFormGroup.notes.rawValue,
        facts: [
          fact("Rating", dive.rating) { "\($0) / 5" },
          RecordInfoFact(label: "Tags", value: dive.tags.joined(separator: ", ")),
          RecordInfoFact(label: "Notes", value: dive.notes, isWide: true),
        ]),
    ]
  }

  /// What an import's new dive shows: its fields, with the cylinders and the recordings the
  /// dive's page gives cards of their own, the dive not having that page yet. A recording's
  /// identifiers are the review's, so nothing here opens one.
  static func reviewInfo(_ dive: DiveReadWithMixtures, units: UnitSystem) -> [RecordInfoSection] {
    var sections = info(dive, units: units)
    if let tanks = tanks(dive, units: units) {
      sections.append(
        RecordInfoSection(
          heading: "Tanks",
          facts: tanks.tanks.enumerated().map { index, tank in
            let pressures =
              tank.start != nil || tank.end != nil
              ? "\(tank.start ?? "—") → \(tank.end ?? "—")" : nil
            let parts = [tank.gas ?? "Gas not recorded", tank.role] + tank.facts + [pressures]
            return RecordInfoFact(
              label: "Tank \(index + 1)", value: parts.compactMap { $0 }.joined(separator: " · "),
              isWide: true)
          }))
    }
    let recordings = dive.recordings.sorted { $0.ordinal < $1.ordinal }
    if !recordings.isEmpty {
      sections.append(
        RecordInfoSection(
          heading: "Recordings",
          facts: recordings.enumerated().map { index, read in
            let shown = recording(read, diveStart: dive.startTime, isOneOfMany: false)
            let files =
              shown.noFileKept.map { [$0] } ?? shown.files.map { $0.name + " · " + $0.detail }
            let lines = [shown.device, shown.settings, shown.readouts, shown.started, shown.firmware]
            let profile = read.profile.map { profileDescription($0, units: units) }
            return RecordInfoFact(
              label: DiveDetailText.recordingLabel(ordinal: index),
              value: (lines + files + [profile]).compactMap { $0 }.joined(separator: "\n"),
              isWide: true)
          }))
    }
    return sections
  }
}
