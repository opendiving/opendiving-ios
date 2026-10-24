extension DiveFormValues {
  /// A queued dive's body as the form reopens on it once the server has refused it: the values
  /// the diver logged, field for field, so *Log dive* sends them again with the corrections.
  /// A tank's linked vessel is not in the body, only its link; the form names it again from
  /// the cached gear.
  public init(create dive: DiveCreate) {
    self.init(
      diveNumber: dive.diveNumber, startTime: dive.startTime,
      submergedTime: DiveDuration.formText(seconds: dive.submergedTime),
      maxDepth: dive.maxDepth, avgDepth: dive.avgDepth,
      bottomTemperature: dive.bottomTemperature, airTemperature: dive.airTemperature,
      visibility: dive.visibility, altitude: dive.altitude, weight: dive.weight,
      rating: dive.rating, waterType: dive.waterType, type: dive.type, current: dive.current,
      waves: dive.waves, weather: dive.weather, entryType: dive.entryType,
      boatName: dive.boatName ?? "", notes: dive.notes, trip: dive.trip, course: dive.course,
      contact: dive.contact, diveSites: dive.diveSites, gearItems: dive.gearItems,
      people: dive.people, sightings: dive.sightings, tags: dive.tags,
      tanks: dive.mixtures.map(TankValues.init(write:)))
  }
}

extension TankValues {
  /// A tank as a write carries it: its link, and no vessel.
  public init(write mixture: DiveMixtureWrite) {
    self.init(
      volume: mixture.volume, startPressure: mixture.startPressure,
      endPressure: mixture.endPressure, oxygen: mixture.oxygen, helium: mixture.helium,
      po2Limit: mixture.po2Limit, gasNumber: mixture.gasNumber, role: mixture.role,
      usage: mixture.usage, cylinder: mixture.gearItem)
  }
}
