extension DiveFormValues {
  /// The new dive's body, `buildDiveCreate`, once the values pass the create rules: an empty
  /// pick-list or reference left out, the boat name trimmed and left out when blank, each tank
  /// as ``TankValues/write``, the dive time in seconds.
  public func toCreate() throws(FormInvalid) -> DiveCreate {
    try validate(for: .create)
    // Validation has guaranteed all three.
    guard let diveNumber, let startTime, let seconds = DiveDuration.seconds(fromForm: submergedTime)
    else { throw FormInvalid(issues: issues(for: .create)) }
    return DiveCreate(
      diveNumber: diveNumber, startTime: startTime, submergedTime: seconds, maxDepth: maxDepth,
      avgDepth: avgDepth, bottomTemperature: bottomTemperature, visibility: visibility,
      weight: weight, waterType: waterType, altitude: altitude, type: type, rating: rating,
      airTemperature: airTemperature, current: current, waves: waves, weather: weather,
      entryType: entryType, boatName: FormText.trimmedOrNil(boatName), notes: notes, trip: trip,
      course: course, contact: contact, mixtures: tanks.map(\.write), diveSites: diveSites,
      gearItems: gearItems, sightings: sightings, people: people, tags: tags)
  }

  /// The edit's body: only what differs from `dive`, the dive as it was loaded — a scalar set
  /// where it changed, `null` for a value or a reference cleared, a list whole where any of it
  /// changed — so an edit kept for a week carries the notes the diver changed and not the
  /// tanks the web changed meanwhile. A field the weather fetch filled (the read's
  /// `conditions.filled`) is never blanked: the API drops that `null`, so it is not sent.
  public func diff(from dive: DiveReadWithMixtures) throws(FormInvalid) -> DiveUpdate {
    try validate(for: .edit)
    let before = DiveFormValues(editing: dive)
    let filled = dive.conditions?.filled
    var update = DiveUpdate()

    if diveNumber != before.diveNumber { update.diveNumber = diveNumber }
    if startTime != before.startTime { update.startTime = startTime }
    let seconds = DiveDuration.seconds(fromForm: submergedTime)
    if seconds != dive.submergedTime { update.submergedTime = seconds }
    if notes != before.notes { update.notes = notes }

    update.maxDepth = Self.patch(maxDepth, before.maxDepth)
    update.avgDepth = Self.patch(avgDepth, before.avgDepth)
    update.bottomTemperature = Self.patch(bottomTemperature, before.bottomTemperature)
    update.visibility = Self.patch(visibility, before.visibility)
    update.weight = Self.patch(weight, before.weight)
    update.waterType = Self.patch(waterType, before.waterType)
    update.altitude = Self.patch(altitude, before.altitude)
    update.type = Self.patch(type, before.type)
    update.rating = Self.patch(rating, before.rating)
    update.airTemperature = Self.patch(
      airTemperature, before.airTemperature, fetched: filled?.airTemperature != nil)
    update.current = Self.patch(current, before.current)
    update.waves = Self.patch(waves, before.waves, fetched: filled?.waves != nil)
    update.weather = Self.patch(weather, before.weather, fetched: filled?.weather != nil)
    update.entryType = Self.patch(entryType, before.entryType)
    update.boatName = Self.patch(
      FormText.trimmedOrNil(boatName), FormText.trimmedOrNil(before.boatName))
    update.trip = Self.patch(trip, before.trip)
    update.course = Self.patch(course, before.course)
    update.contact = Self.patch(contact, before.contact)

    let mixtures = tanks.map(\.write)
    if mixtures != before.tanks.map(\.write) { update.mixtures = mixtures }
    if diveSites != before.diveSites { update.diveSites = diveSites }
    if gearItems != before.gearItems { update.gearItems = gearItems }
    if sightings != before.sightings { update.sightings = sightings }
    if people != before.people { update.people = people }
    if tags != before.tags { update.tags = tags }
    return update
  }

  /// A scalar's member of the update: absent while unchanged, and absent too for a fetched
  /// value cleared, which the API would ignore.
  private static func patch<Value: Hashable & Sendable>(_ now: Value?, _ before: Value?, fetched: Bool = false)
    -> Patch<Value>
  {
    guard now != before else { return .absent }
    guard let now else { return fetched ? .absent : .null }
    return .value(now)
  }
}
