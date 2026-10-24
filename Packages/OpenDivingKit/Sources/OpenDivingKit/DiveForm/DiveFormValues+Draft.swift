extension DiveFormValues {
  /// The form as a dive draft's body: what the diver has filled and nothing else, and the set
  /// loaded as a checklist, whose ticked items are already the values' gear. A draft begun on
  /// the phone opens on the laptop as it was left, and the other way round.
  ///
  /// Three things a form can hold have no place in a draft and are left out: a dive time that
  /// is not yet minutes or `MM:SS`, a start without an offset (the server refuses one), and a
  /// tank's read vessel, which the link names and the cached gear describes again.
  public func draft(gearSet: RecordRef?) -> DiveDraftWrite {
    var values = DiveDraftValues()
    values.diveNumber = diveNumber
    if case .instant = startTime { values.startTime = startTime }
    values.submergedTime = DiveDuration.seconds(fromForm: submergedTime)
    values.maxDepth = maxDepth
    values.avgDepth = avgDepth
    values.bottomTemperature = bottomTemperature
    values.visibility = visibility
    values.weight = weight
    values.waterType = waterType
    values.altitude = altitude
    values.type = type
    values.rating = rating
    values.airTemperature = airTemperature
    values.current = current
    values.waves = waves
    values.weather = weather
    values.entryType = entryType
    values.boatName = boatName.isEmpty ? nil : boatName
    values.notes = notes.isEmpty ? nil : notes
    values.trip = trip
    values.course = course
    values.contact = contact
    values.mixtures = tanks.isEmpty ? nil : tanks.map(Self.draftTank)
    values.diveSites = diveSites.isEmpty ? nil : diveSites
    values.gearItems = gearItems.isEmpty ? nil : gearItems
    values.sightings = sightings.isEmpty ? nil : sightings
    values.people = people.isEmpty ? nil : people
    values.tags = tags.isEmpty ? nil : tags
    return DiveDraftWrite(gearSet: gearSet, values: values)
  }

  /// A draft's values as the form opens on them; the draft's gear set is the caller's to open
  /// as a checklist from the cached sets.
  public init(draft: DiveDraftValues) {
    self.init(
      diveNumber: draft.diveNumber, startTime: draft.startTime,
      submergedTime: draft.submergedTime.map { DiveDuration.formText(seconds: $0) } ?? "",
      maxDepth: draft.maxDepth, avgDepth: draft.avgDepth,
      bottomTemperature: draft.bottomTemperature, airTemperature: draft.airTemperature,
      visibility: draft.visibility, altitude: draft.altitude, weight: draft.weight,
      rating: draft.rating, waterType: draft.waterType, type: draft.type, current: draft.current,
      waves: draft.waves, weather: draft.weather, entryType: draft.entryType,
      boatName: draft.boatName ?? "", notes: draft.notes ?? "", trip: draft.trip,
      course: draft.course, contact: draft.contact, diveSites: draft.diveSites ?? [],
      gearItems: draft.gearItems ?? [], people: draft.people ?? [],
      sightings: draft.sightings ?? [], tags: draft.tags ?? [],
      tanks: (draft.mixtures ?? []).map(Self.formTank))
  }

  /// The tank as typed, its own volume and not the vessel's: the draft keeps the form's state.
  private static func draftTank(_ tank: TankValues) -> DiveMixtureWrite {
    var write = tank.write
    write.volume = tank.volume
    return write
  }

  private static func formTank(_ mixture: DiveMixtureWrite) -> TankValues {
    TankValues(
      volume: mixture.volume, startPressure: mixture.startPressure,
      endPressure: mixture.endPressure, oxygen: mixture.oxygen, helium: mixture.helium,
      po2Limit: mixture.po2Limit, gasNumber: mixture.gasNumber, role: mixture.role,
      usage: mixture.usage, cylinder: mixture.gearItem)
  }
}
