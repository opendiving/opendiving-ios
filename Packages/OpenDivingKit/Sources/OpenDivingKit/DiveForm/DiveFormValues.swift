import Foundation

/// What the dive form holds, one member per field: metric whatever the diver types in, shaped
/// like the wire, and incomplete by design — a half-filled form is what a draft is. It becomes a
/// body only through ``toCreate()`` or ``diff(from:)``, each of which validates first.
///
/// Blank is nil for a number, a pick-list or a reference, `""` for the boat name and the notes,
/// and an empty list for a list. The dive time is kept as typed, minutes or `MM:SS`.
public struct DiveFormValues: Codable, Hashable, Sendable {
  public var diveNumber: Int?
  public var startTime: DiveTimestamp?
  /// As typed: `45` or `45:30`.
  public var submergedTime: String
  /// Metres.
  public var maxDepth: Double?
  public var avgDepth: Double?
  /// °C.
  public var bottomTemperature: Double?
  public var airTemperature: Double?
  /// Whole metres.
  public var visibility: Int?
  /// Whole metres above sea level.
  public var altitude: Int?
  /// Kilograms.
  public var weight: Double?
  /// 1 to 5; nil is unrated.
  public var rating: Int?
  public var waterType: String?
  public var type: String?
  public var current: String?
  public var waves: String?
  public var weather: String?
  public var entryType: String?
  public var boatName: String
  public var notes: String
  public var trip: RecordRef?
  public var course: RecordRef?
  /// The dive centre.
  public var contact: RecordRef?
  /// In the order visited; the first is the primary.
  public var diveSites: [RecordRef]
  public var gearItems: [RecordRef]
  public var people: [PersonReference]
  public var sightings: [SightingWrite]
  public var tags: [String]
  public var tanks: [TankValues]

  public init(
    diveNumber: Int? = nil, startTime: DiveTimestamp? = nil, submergedTime: String = "",
    maxDepth: Double? = nil, avgDepth: Double? = nil, bottomTemperature: Double? = nil,
    airTemperature: Double? = nil, visibility: Int? = nil, altitude: Int? = nil,
    weight: Double? = nil, rating: Int? = nil, waterType: String? = nil, type: String? = nil,
    current: String? = nil, waves: String? = nil, weather: String? = nil,
    entryType: String? = nil, boatName: String = "", notes: String = "",
    trip: RecordRef? = nil, course: RecordRef? = nil, contact: RecordRef? = nil,
    diveSites: [RecordRef] = [], gearItems: [RecordRef] = [], people: [PersonReference] = [],
    sightings: [SightingWrite] = [], tags: [String] = [], tanks: [TankValues] = []
  ) {
    self.diveNumber = diveNumber
    self.startTime = startTime
    self.submergedTime = submergedTime
    self.maxDepth = maxDepth
    self.avgDepth = avgDepth
    self.bottomTemperature = bottomTemperature
    self.airTemperature = airTemperature
    self.visibility = visibility
    self.altitude = altitude
    self.weight = weight
    self.rating = rating
    self.waterType = waterType
    self.type = type
    self.current = current
    self.waves = waves
    self.weather = weather
    self.entryType = entryType
    self.boatName = boatName
    self.notes = notes
    self.trip = trip
    self.course = course
    self.contact = contact
    self.diveSites = diveSites
    self.gearItems = gearItems
    self.people = people
    self.sightings = sightings
    self.tags = tags
    self.tanks = tanks
  }

  /// The dive as the edit form opens on it, field for field (`diveToFormValues`): the form
  /// sends what changed against this, so nothing here may be invented.
  public init(editing dive: DiveReadWithMixtures) {
    self.init(
      diveNumber: dive.diveNumber, startTime: dive.startTime,
      submergedTime: DiveDuration.formText(seconds: dive.submergedTime),
      maxDepth: dive.maxDepth, avgDepth: dive.avgDepth,
      bottomTemperature: dive.bottomTemperature, airTemperature: dive.airTemperature,
      visibility: dive.visibility, altitude: dive.altitude, weight: dive.weight,
      rating: dive.rating, waterType: dive.waterType, type: dive.type, current: dive.current,
      waves: dive.waves, weather: dive.weather, entryType: dive.entryType,
      boatName: dive.boatName ?? "", notes: dive.notes, trip: dive.tripUuid.map(RecordRef.server),
      course: dive.courseUuid.map(RecordRef.server),
      contact: dive.contactUuid.map(RecordRef.server), diveSites: dive.diveSites.map(\.ref),
      gearItems: dive.gearItems.map(\.ref), people: dive.people,
      sightings: dive.sightings.map {
        SightingWrite(speciesUuid: $0.uuid, count: $0.count, abundance: $0.abundance, notes: $0.notes)
      },
      tags: dive.tags, tanks: dive.mixtures.map(TankValues.init))
  }

  /// A new dive's form before anything is carried into it: numbered, if a number is known,
  /// and starting now on the phone's clock with its offset (`nowStartTime`).
  public static func newDive(
    number: Int?, now: Date = Date(), timeZone: TimeZone = .current
  ) -> DiveFormValues {
    DiveFormValues(diveNumber: number, startTime: DiveStart.now(now, in: timeZone))
  }

  /// Every field these values hold something in, in form order — what a value arriving from
  /// outside the diver's typing puts back on screen (`nonEmptyDiveFormFields`). A `mixture.`
  /// column counts when any tank holds a value in it; helium's `0` is not one.
  public var nonEmptyFields: [DiveFormField] {
    DiveFormField.allCases.filter { field in
      if field.isMixtureColumn { return tanks.contains { $0.reveals(field) } }
      return holdsValue(field)
    }
  }

  /// Whether one dive-level field holds something.
  public func holdsValue(_ field: DiveFormField) -> Bool {
    switch field {
    case .fileImport: false
    case .course: course != nil
    case .trip: trip != nil
    case .contact: contact != nil
    case .diveSites: !diveSites.isEmpty
    case .entryType: entryType != nil
    case .boatName: !boatName.isEmpty
    case .people: !people.isEmpty
    case .type: type != nil
    case .maxDepth: maxDepth != nil
    case .avgDepth: avgDepth != nil
    case .bottomTemperature: bottomTemperature != nil
    case .visibility: visibility != nil
    case .waterType: waterType != nil
    case .altitude: altitude != nil
    case .waves: waves != nil
    case .current: current != nil
    case .weather: weather != nil
    case .airTemperature: airTemperature != nil
    case .mixtures: !tanks.isEmpty
    case .gearItems: !gearItems.isEmpty
    case .weight: weight != nil
    case .sightings: !sightings.isEmpty
    case .rating: rating != nil
    case .tags: !tags.isEmpty
    case .notes: !notes.isEmpty
    case .mixtureCylinder, .mixturePo2Limit, .mixtureHelium, .mixtureStartPressure,
      .mixtureEndPressure, .mixtureUsage, .mixtureRole:
      tanks.contains { $0.reveals(field) }
    }
  }

  /// Empties one field: the dive-level value, or one column on every tank.
  public mutating func clear(_ field: DiveFormField) {
    switch field {
    case .fileImport: break
    case .course: course = nil
    case .trip: trip = nil
    case .contact: contact = nil
    case .diveSites: diveSites = []
    case .entryType: entryType = nil
    case .boatName: boatName = ""
    case .people: people = []
    case .type: type = nil
    case .maxDepth: maxDepth = nil
    case .avgDepth: avgDepth = nil
    case .bottomTemperature: bottomTemperature = nil
    case .visibility: visibility = nil
    case .waterType: waterType = nil
    case .altitude: altitude = nil
    case .waves: waves = nil
    case .current: current = nil
    case .weather: weather = nil
    case .airTemperature: airTemperature = nil
    case .mixtures: tanks = []
    case .gearItems: gearItems = []
    case .weight: weight = nil
    case .sightings: sightings = []
    case .rating: rating = nil
    case .tags: tags = []
    case .notes: notes = ""
    case .mixtureCylinder, .mixturePo2Limit, .mixtureHelium, .mixtureStartPressure,
      .mixtureEndPressure, .mixtureUsage, .mixtureRole:
      for index in tanks.indices { tanks[index].clear(field) }
    }
  }
}

extension DiveFormValues: RewritesLocalRefs {
  public mutating func rewriteRefs(_ rewrite: (RecordRef) -> RecordRef?) {
    trip.rewrite(rewrite)
    course.rewrite(rewrite)
    contact.rewrite(rewrite)
    diveSites.rewrite(rewrite)
    gearItems.rewrite(rewrite)
    people.rewritePeople(rewrite)
    tanks.rewriteEach(rewrite)
  }
}
