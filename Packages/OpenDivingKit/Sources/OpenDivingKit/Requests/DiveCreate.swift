import Foundation

/// `POST /dive`'s body, `DiveCreateRequest`, and the body `POST /dive-draft/{uuid}/dive` logs a
/// draft with. Measurements are metric whatever the account's units.
public struct DiveCreate: Codable, Hashable, Sendable {
  public var diveNumber: Int
  /// With its offset: a create without one is refused.
  public var startTime: DiveTimestamp
  /// Seconds in the water.
  public var submergedTime: Int
  public var maxDepth: Double?
  public var avgDepth: Double?
  public var bottomTemperature: Double?
  /// Whole metres.
  public var visibility: Int?
  /// Kilograms.
  public var weight: Double?
  public var waterType: String?
  /// Whole metres above sea level.
  public var altitude: Int?
  public var type: String?
  /// 1 to 5.
  public var rating: Int?
  public var airTemperature: Double?
  public var current: String?
  public var waves: String?
  public var weather: String?
  public var entryType: String?
  public var boatName: String?
  public var notes: String
  public var trip: RecordRef?
  public var course: RecordRef?
  /// The dive centre that ran the dive.
  public var contact: RecordRef?
  public var mixtures: [DiveMixtureWrite]
  /// In the order visited.
  public var diveSites: [RecordRef]
  public var gearItems: [RecordRef]
  public var sightings: [SightingWrite]
  public var people: [PersonReference]
  public var tags: [String]

  enum CodingKeys: String, CodingKey {
    case diveNumber, startTime, submergedTime, maxDepth, avgDepth, bottomTemperature, visibility,
      weight, waterType, altitude, type, rating, airTemperature, current, waves, weather,
      entryType, boatName, notes, mixtures, sightings, people, tags
    case trip = "tripUuid"
    case course = "courseUuid"
    case contact = "contactUuid"
    case diveSites = "diveSiteUuids"
    case gearItems = "gearItemUuids"
  }

  public init(
    diveNumber: Int, startTime: DiveTimestamp, submergedTime: Int, maxDepth: Double? = nil,
    avgDepth: Double? = nil, bottomTemperature: Double? = nil, visibility: Int? = nil,
    weight: Double? = nil, waterType: String? = nil, altitude: Int? = nil, type: String? = nil,
    rating: Int? = nil, airTemperature: Double? = nil, current: String? = nil,
    waves: String? = nil, weather: String? = nil, entryType: String? = nil,
    boatName: String? = nil, notes: String = "", trip: RecordRef? = nil,
    course: RecordRef? = nil, contact: RecordRef? = nil, mixtures: [DiveMixtureWrite] = [],
    diveSites: [RecordRef] = [], gearItems: [RecordRef] = [], sightings: [SightingWrite] = [],
    people: [PersonReference] = [], tags: [String] = []
  ) {
    self.diveNumber = diveNumber
    self.startTime = startTime
    self.submergedTime = submergedTime
    self.maxDepth = maxDepth
    self.avgDepth = avgDepth
    self.bottomTemperature = bottomTemperature
    self.visibility = visibility
    self.weight = weight
    self.waterType = waterType
    self.altitude = altitude
    self.type = type
    self.rating = rating
    self.airTemperature = airTemperature
    self.current = current
    self.waves = waves
    self.weather = weather
    self.entryType = entryType
    self.boatName = boatName
    self.notes = notes
    self.trip = trip
    self.course = course
    self.contact = contact
    self.mixtures = mixtures
    self.diveSites = diveSites
    self.gearItems = gearItems
    self.sightings = sightings
    self.people = people
    self.tags = tags
  }
}

extension DiveCreate: RewritesLocalRefs {
  public mutating func rewriteRefs(_ rewrite: (RecordRef) -> RecordRef?) {
    trip.rewrite(rewrite)
    course.rewrite(rewrite)
    contact.rewrite(rewrite)
    mixtures.rewriteEach(rewrite)
    diveSites.rewrite(rewrite)
    gearItems.rewrite(rewrite)
    people.rewritePeople(rewrite)
  }
}
