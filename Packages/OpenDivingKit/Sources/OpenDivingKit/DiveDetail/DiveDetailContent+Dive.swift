import Foundation

extension DiveDetailContent {
  /// The sentence for a dive with a cylinder and no gas-use figures. One sentence rather
  /// than the web's explainer of each reason, which reads the dive's own fields.
  public static let gasUseUnavailable =
    "Gas consumption could not be worked out from what this dive records."

  /// The dive's page from `GET /dive/{uuid}` and what it names: the trip, the course and
  /// the dive centre, each nil when the dive has none or its read failed, and the people
  /// table that names `people`.
  public init(
    dive: DiveReadWithMixtures,
    trip: TripRead?,
    course: CourseRead?,
    contact: ContactRead?,
    people: [UUID: PersonRead],
    units: UnitSystem
  ) {
    let recordings = dive.recordings.sorted { $0.ordinal < $1.ordinal }
    navigationTitle = "#\(dive.diveNumber)"
    hero = Self.hero(dive, hasRecording: !recordings.isEmpty, units: units)
    profile = Self.profile(dive, recordings: recordings, units: units)
    tanks = Self.tanks(dive, units: units)
    gasConsumption = Self.gasConsumption(dive, units: units)
    exposure = recordings.first.flatMap(Self.exposure)
    gear = Self.gear(dive, units: units)
    sightings = dive.sightings.map(Self.sighting)
    notes = dive.notes.isEmpty ? nil : dive.notes
    self.course = course?.name
    location = Self.location(dive, trip: trip, contact: contact, units: units)
    self.people = PersonRowContent.rows(dive.people, people: people)
    environment = Self.environment(dive.dive, units: units)
    self.recordings = recordings.map {
      Self.recording($0, diveStart: dive.startTime, isOneOfMany: recordings.count > 1)
    }
  }

  // MARK: - Hero

  /// The card's chips, title and facts, over the dive's figures in the web's order: the
  /// dive time, the max depth, the average only while fewer than four figures would show,
  /// then the water temperature and the visibility.
  static func hero(_ dive: DiveReadWithMixtures, hasRecording: Bool, units: UnitSystem)
    -> HeroContent
  {
    let card = DiveCardContent.dive(
      number: dive.diveNumber, siteNames: dive.diveSites.map(\.name),
      isCourse: dive.courseUuid != nil, rating: dive.rating, waterType: dive.waterType,
      diveType: dive.type, tags: dive.tags, start: dive.startTime,
      locationName: dive.diveSites.first?.location?.name, boatName: dive.boatName,
      hasRecording: hasRecording, submergedSeconds: dive.submergedTime,
      maxDepth: dive.maxDepth, avgDepth: dive.avgDepth,
      waterTemperature: dive.bottomTemperature, outline: [], units: units)

    let wholeDepth = { (meters: Double) in UnitFormat.depth(meters, units, decimals: 0) }
    var figures = [
      Figure(label: "Dive time", value: DateText.hoursMinutes(seconds: dive.submergedTime))
    ]
    if let maxDepth = dive.maxDepth {
      figures.append(Figure(label: "Max depth", value: wholeDepth(maxDepth)))
    }
    var readings: [Figure] = []
    if let temperature = dive.bottomTemperature {
      readings.append(
        Figure(
          label: "Water temp", value: UnitFormat.temperature(temperature, units, decimals: 0)))
    }
    if let visibility = dive.visibility {
      readings.append(
        Figure(label: "Visibility", value: UnitFormat.visibility(Double(visibility), units)))
    }
    if let avgDepth = dive.avgDepth, figures.count + readings.count < 4 {
      figures.append(Figure(label: "Avg depth", value: wholeDepth(avgDepth)))
    }
    figures += readings

    let points = dive.diveSites.compactMap { site -> MapPoint? in
      guard let latitude = site.latitude, let longitude = site.longitude else { return nil }
      return MapPoint(name: site.name, latitude: latitude, longitude: longitude)
    }
    var fixes: [MapPoint] = []
    if let latitude = dive.entryLatitude, let longitude = dive.entryLongitude {
      fixes.append(MapPoint(name: "Entry", latitude: latitude, longitude: longitude))
    }
    if let latitude = dive.exitLatitude, let longitude = dive.exitLongitude {
      fixes.append(MapPoint(name: "Exit", latitude: latitude, longitude: longitude))
    }
    return HeroContent(
      title: card.title, isCourse: card.isCourse, rating: card.rating, chips: card.chips,
      facts: card.facts, figures: figures, points: points, fixes: fixes)
  }

  // MARK: - Main column

  static func profile(
    _ dive: DiveReadWithMixtures, recordings: [RecordingRead], units: UnitSystem
  ) -> Profile? {
    let charted = recordings.compactMap { recording -> Profile.ChartedRecording? in
      guard let info = recording.profile else { return nil }
      let device = recording.device.flatMap {
        RecordingLabels.device(brand: $0.brand, model: $0.model, serial: $0.serial, name: $0.name)
      }
      return Profile.ChartedRecording(
        id: recording.uuid,
        label: device
          ?? RecordingLabels.unnamedDevice + " · "
          + DiveDetailText.recordingLabel(ordinal: recording.ordinal),
        description: profileDescription(info, units: units))
    }
    guard !charted.isEmpty else { return nil }
    return Profile(cylinderLabels: dive.mixtures.map(\.gasNumber), recordings: charted)
  }

  /// What the computer recorded, from the summary rather than the series: the sample
  /// count, the markers when there are any, and the deepest ceiling at one decimal.
  static func profileDescription(_ info: DiveProfileInfo, units: UnitSystem) -> String {
    var parts = [
      NumberText.grouped(info.depthSampleCount) + " depth samples recorded by the dive computer"
    ]
    if let events = info.eventCount, events > 0 {
      parts.append(DiveDetailText.countNoun(events, "marker"))
    }
    if let ceiling = info.maxCeiling {
      parts.append("a deco ceiling to " + UnitFormat.depth(ceiling, units, decimals: 1))
    }
    return parts.joined(separator: ", ") + "."
  }

  static func tanks(_ dive: DiveReadWithMixtures, units: UnitSystem) -> Tanks? {
    let mixtures = dive.mixtures
    guard !mixtures.isEmpty else { return nil }
    let fractions = mixtures.map {
      OxygenFractions(oxygen: $0.oxygen, helium: $0.helium, usage: $0.usage)
    }
    let warning = GasMath.diveModWarning(fractions, maxDepth: dive.maxDepth, units: units)
    // Only where the sentence is about one gas — a single cylinder, or a parallel set of
    // one gas — does marking a cylinder point at what it says.
    let attributable =
      warning != nil && (mixtures.count == 1 || GasMath.isSingleGasParallelSet(fractions))
    let showHelium = mixtures.contains { ($0.helium ?? 0) > 0 }

    let cards = mixtures.enumerated().map { index, mixture in
      var facts: [String] = []
      if let item = mixture.gearItem {
        facts.append(DiveDetailText.gearItemLabel(name: item.name, brand: item.brand))
      }
      if let volume = mixture.volume { facts.append(NumberText.plain(volume) + " L") }
      if let oxygen = mixture.oxygen { facts.append("O₂ " + NumberText.plain(oxygen) + "%") }
      if showHelium, let helium = mixture.helium {
        facts.append("He " + NumberText.plain(helium) + "%")
      }
      if let usage = mixture.usage, !usage.isEmpty {
        facts.append(VocabularyLabels.tankUsage(usage))
      }
      let limit = GasMath.ppO2Limit(recorded: mixture.po2Limit)
      let workingMod =
        GasMath.isNameable(oxygen: mixture.oxygen, helium: mixture.helium)
        ? GasMath.mod(oxygen: mixture.oxygen, ppO2: limit) : nil
      return Tanks.Tank(
        number: "#\(index + 1)",
        gas: GasMath.name(oxygen: mixture.oxygen, helium: mixture.helium),
        role: mixture.role.flatMap { $0.isEmpty ? nil : VocabularyLabels.gasRole($0) },
        facts: facts,
        start: mixture.startPressure.map { UnitFormat.pressure($0, units) },
        end: mixture.endPressure.map { UnitFormat.pressure($0, units) },
        modCondition: workingMod.map { _ in "@ " + NumberText.plain(limit) },
        mod: workingMod.map { UnitFormat.comparableDepth($0, units, floor: true) },
        warned: attributable)
    }
    return Tanks(tanks: cards, warning: warning)
  }

  static func gasConsumption(_ dive: DiveReadWithMixtures, units: UnitSystem)
    -> GasConsumption?
  {
    guard !dive.mixtures.isEmpty else { return nil }
    guard let gasUse = dive.gasUse else { return .unavailable(gasUseUnavailable) }

    let rows = TankGasUseRow.rows(mixtures: dive.mixtures, gasUse: gasUse)
    let sac = { (barPerMinute: Double?) in barPerMinute.map { UnitFormat.sac($0, units) } }
    guard !rows.isEmpty else {
      let figures = [
        Figure(label: "RMV", value: UnitFormat.rmv(gasUse.rmv, units)),
        Figure(label: "SAC", value: sac(gasUse.sacBarPerMin)),
        Figure(label: "Gas used", value: UnitFormat.gasVolume(gasUse.gasUsed, units)),
      ]
      let note = dive.avgDepth.map {
        "What you'd have breathed doing the same dive at the surface, from an average depth "
          + "of \(UnitFormat.depth($0, units)). Assumes salt water at sea level. Lower is better."
      }
      return .figures(figures, note: note)
    }

    let tableRows = rows.map { row in
      GasRow(
        label: row.label,
        gas: row.gas,
        role: row.role.flatMap { $0.isEmpty ? nil : VocabularyLabels.gasRole($0) },
        cells: row.use.map { use in
          [
            DiveDetailText.timeOnGas(seconds: use.secondsOnGas),
            UnitFormat.depth(use.meanDepth, units),
            UnitFormat.gasVolume(use.gasUsed, units),
            UnitFormat.rmv(use.rmv, units),
            UnitFormat.sac(use.sacBarPerMin, units),
          ]
        },
        emptyText: row.use == nil
          ? (row.hasPressures ? "No figures" : "No pressures recorded") : nil)
    }
    // A total is worth a row only when it totals more than one attributed cylinder.
    let total =
      rows.filter { $0.use != nil }.count > 1
      ? GasRow(
        label: "Total", gas: nil, role: nil,
        cells: [
          gasUse.attributedSeconds.map { DiveDetailText.timeOnGas(seconds: $0) } ?? "-",
          "-",
          UnitFormat.gasVolume(gasUse.gasUsed, units),
          UnitFormat.rmv(gasUse.rmv, units),
          sac(gasUse.sacBarPerMin) ?? "-",
        ],
        emptyText: nil) : nil
    return .table(
      rows: tableRows, total: total,
      note: "Each tank's figures cover the stretch of the dive it was breathed for, at that "
        + "stretch's average depth — which is what makes them comparable with each other and "
        + "with a single-tank dive. Assumes salt water at sea level. Lower is better.",
      coverage: DiveDetailText.gasAttributionNote(
        attributedSeconds: gasUse.attributedSeconds, duration: gasUse.duration))
  }

  /// The CNS clock past which a dive is over the accepted single-dive exposure.
  static let cnsLimitPercent = 100.0

  /// The primary recording's readouts, exactly as stored.
  static func exposure(_ primary: RecordingRead) -> Exposure? {
    let side = { (value: Double?, unit: String) in value.map { NumberText.plain($0) + unit } }
    var readings: [Exposure.Reading] = []
    if primary.cnsStart != nil || primary.cnsEnd != nil {
      let over = (primary.cnsEnd ?? 0) >= cnsLimitPercent
      readings.append(
        Exposure.Reading(
          label: "CNS", start: side(primary.cnsStart, "%") ?? "—",
          end: side(primary.cnsEnd, "%") ?? "—",
          alert: over ? "over the \(NumberText.plain(cnsLimitPercent))% single-dive limit" : nil))
    }
    if primary.otuStart != nil || primary.otuEnd != nil {
      readings.append(
        Exposure.Reading(
          label: "OTU", start: side(primary.otuStart, "") ?? "—",
          end: side(primary.otuEnd, "") ?? "—", alert: nil))
    }
    let pressure = side(primary.surfacePressureBar, " bar")
    guard !readings.isEmpty || pressure != nil else { return nil }
    return Exposure(readings: readings, surfacePressure: pressure)
  }

  static func gear(_ dive: DiveReadWithMixtures, units: UnitSystem) -> Gear? {
    guard !dive.gearItems.isEmpty || dive.weight != nil else { return nil }
    return Gear(
      items: dive.gearItems.map {
        Gear.Item(
          type: VocabularyLabels.gearType($0.type) ?? "-",
          brand: $0.brand.flatMap { $0.isEmpty ? nil : $0 } ?? "-",
          name: $0.name, rented: $0.rented, archived: $0.isArchived)
      },
      weight: dive.weight.map { UnitFormat.weight($0, units) })
  }

  /// A count, or a band with its range, and no figure for seen-not-counted, which is not 1.
  static func sighting(_ sighting: SightingRead) -> Sighting {
    var figures: [Figure] = []
    if let count = sighting.count {
      figures.append(Figure(label: "Count", value: String(count)))
    } else if let band = sighting.abundance {
      let range = VocabularyLabels.abundanceRange(band).map { " " + $0 } ?? ""
      figures.append(Figure(label: "Abundance", value: VocabularyLabels.abundance(band) + range))
    }
    return Sighting(
      id: sighting.uuid,
      photoVersion: sighting.photoSha256,
      card: SpeciesCardContent(
        commonName: SpeciesNames.displayName(
          scientificName: sighting.scientificName, commonName: sighting.commonName),
        scientificName: SpeciesNames.scientificNameWithRank(
          sighting.scientificName, rank: sighting.rank),
        figures: figures,
        note: sighting.notes.isEmpty ? nil : sighting.notes))
  }

  // MARK: - Sidebar

  static func location(
    _ dive: DiveReadWithMixtures, trip: TripRead?, contact: ContactRead?, units: UnitSystem
  ) -> Location? {
    let entry = CoordinateFormat.format(
      latitude: dive.entryLatitude, longitude: dive.entryLongitude)
    let exit = CoordinateFormat.format(latitude: dive.exitLatitude, longitude: dive.exitLongitude)
    guard
      trip != nil || contact != nil || !dive.diveSites.isEmpty || dive.entryType != nil
        || dive.boatName != nil || entry != nil || exit != nil
    else { return nil }

    var drift: String?
    if let entryLatitude = dive.entryLatitude, let entryLongitude = dive.entryLongitude,
      let exitLatitude = dive.exitLatitude, let exitLongitude = dive.exitLongitude
    {
      drift = GeoDistance.format(
        GeoDistance.haversineMeters(
          fromLatitude: entryLatitude, longitude: entryLongitude, toLatitude: exitLatitude,
          longitude: exitLongitude),
        units)
    }

    return Location(
      trip: trip.map {
        Location.Trip(
          uuid: $0.uuid, name: $0.name,
          locations: TripText.locationsLabel($0.parts.map { $0.location?.name }))
      },
      diveCenter: contact.map(diveCenter),
      sitesLabel: dive.diveSites.count > 1 ? "Dive sites" : "Dive site",
      sites: dive.diveSites.map {
        Location.Site(
          id: $0.uuid, name: $0.name,
          location: $0.location.flatMap { $0.name.isEmpty ? nil : $0.name })
      },
      entry: entry,
      exit: exit,
      drift: drift,
      entryType: dive.entryType.map(VocabularyLabels.entryType),
      boatName: dive.boatName)
  }

  static func diveCenter(_ contact: ContactRead) -> Location.DiveCenter {
    let phone = contact.phone.flatMap { $0.isEmpty ? nil : $0 }
    let website = contact.website.flatMap { $0.isEmpty ? nil : $0 }
    return Location.DiveCenter(
      name: contact.name,
      place: DiveDetailText.contactAddress([
        contact.address?.city, contact.address?.region, contact.address?.country,
      ]),
      phone: phone,
      phoneURL: phone.flatMap { URL(string: "tel:" + DiveDetailText.dialable($0)) },
      website: website.map(DiveDetailText.website),
      websiteURL: website.flatMap(URL.init(string:)))
  }

  static func environment(_ dive: DiveRead, units: UnitSystem) -> [Figure] {
    var figures: [Figure] = []
    if let air = dive.airTemperature {
      figures.append(Figure(label: "Air temperature", value: UnitFormat.temperature(air, units)))
    }
    if let water = dive.waterType {
      figures.append(Figure(label: "Water type", value: VocabularyLabels.waterType(water)))
    }
    if let altitude = dive.altitude {
      figures.append(Figure(label: "Altitude", value: UnitFormat.altitude(Double(altitude), units)))
    }
    if let current = dive.current {
      figures.append(Figure(label: "Current", value: VocabularyLabels.current(current)))
    }
    if let waves = dive.waves {
      figures.append(Figure(label: "Waves", value: VocabularyLabels.waves(waves)))
    }
    if let weather = dive.weather {
      figures.append(Figure(label: "Weather", value: VocabularyLabels.weather(weather)))
    }
    return figures
  }

  static func recording(_ recording: RecordingRead, diveStart: DiveTimestamp, isOneOfMany: Bool)
    -> Recording
  {
    let device = recording.device
    var name: String?
    if isOneOfMany {
      name =
        DiveDetailText.recordingLabel(ordinal: recording.ordinal)
        + (recording.ordinal == 0 ? " · shown by default" : "")
    }
    let deco = recording.decoModel
    return Recording(
      id: recording.uuid,
      device: device.flatMap {
        RecordingLabels.device(brand: $0.brand, model: $0.model, serial: $0.serial, name: $0.name)
      } ?? RecordingLabels.unnamedDevice,
      name: name,
      settings: RecordingLabels.settings(
        mode: recording.mode, decoName: deco?.name, decoAlgorithm: deco?.algorithm,
        gfLow: deco?.gfLow, gfHigh: deco?.gfHigh, conservatism: deco?.conservatism,
        salinity: recording.salinity),
      readouts: RecordingLabels.readouts(
        cnsStart: recording.cnsStart, cnsEnd: recording.cnsEnd, otuStart: recording.otuStart,
        otuEnd: recording.otuEnd, surfacePressureBar: recording.surfacePressureBar),
      started: recording.startedAt.flatMap {
        $0 == diveStart ? nil : "Started " + DateText.diveTime($0)
      },
      firmware: device?.firmware.flatMap { $0.isEmpty ? nil : "Firmware " + $0 },
      noFileKept: DiveDetailText.noFileKeptSentence(
        fileCount: recording.files.count, provenance: recording.profile?.provenance),
      files: recording.files.map {
        Recording.File(
          id: $0.uuid, name: $0.originalFilename,
          detail: VocabularyLabels.importSource($0.parserKey) + " · "
            + DiveDetailText.fileSize($0.byteSize))
      })
  }
}
