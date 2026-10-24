import Foundation

/// `PATCH /dive/{uuid}`'s body, `DiveUpdateRequest`, which carries only what the diver changed:
/// a member left ``Patch/absent`` or nil is not sent and the server keeps what it holds.
///
/// The four members the API refuses a null for — the number, the start, the time in the water
/// and the notes — are optionals, so a null cannot be written for them. Every other scalar is a
/// ``Patch``, where ``Patch/null`` clears the value and, on the trip, the course and the
/// contact, detaches the dive. A list replaces the dive's whole list whenever it is sent.
public struct DiveUpdate: Codable, Hashable, Sendable {
  public var diveNumber: Int?
  public var startTime: DiveTimestamp?
  public var submergedTime: Int?
  public var notes: String?
  public var maxDepth: Patch<Double>
  public var avgDepth: Patch<Double>
  public var bottomTemperature: Patch<Double>
  public var visibility: Patch<Int>
  public var weight: Patch<Double>
  public var waterType: Patch<String>
  public var altitude: Patch<Int>
  public var type: Patch<String>
  public var rating: Patch<Int>
  public var airTemperature: Patch<Double>
  public var current: Patch<String>
  public var waves: Patch<String>
  public var weather: Patch<String>
  public var entryType: Patch<String>
  public var boatName: Patch<String>
  public var trip: Patch<RecordRef>
  public var course: Patch<RecordRef>
  public var contact: Patch<RecordRef>
  public var mixtures: [DiveMixtureWrite]?
  public var diveSites: [RecordRef]?
  public var gearItems: [RecordRef]?
  public var sightings: [SightingWrite]?
  public var people: [PersonReference]?
  public var tags: [String]?

  enum CodingKeys: String, CodingKey {
    case diveNumber, startTime, submergedTime, notes, maxDepth, avgDepth, bottomTemperature,
      visibility, weight, waterType, altitude, type, rating, airTemperature, current, waves,
      weather, entryType, boatName, mixtures, sightings, people, tags
    case trip = "tripUuid"
    case course = "courseUuid"
    case contact = "contactUuid"
    case diveSites = "diveSiteUuids"
    case gearItems = "gearItemUuids"
  }

  /// An update that changes nothing; set what changed.
  public init() {
    maxDepth = .absent
    avgDepth = .absent
    bottomTemperature = .absent
    visibility = .absent
    weight = .absent
    waterType = .absent
    altitude = .absent
    type = .absent
    rating = .absent
    airTemperature = .absent
    current = .absent
    waves = .absent
    weather = .absent
    entryType = .absent
    boatName = .absent
    trip = .absent
    course = .absent
    contact = .absent
  }

  /// Whether sending it would change nothing.
  public var isEmpty: Bool { self == DiveUpdate() }
}

extension DiveUpdate: RewritesLocalRefs {
  public mutating func rewriteRefs(_ rewrite: (RecordRef) -> RecordRef?) {
    trip.rewrite(rewrite)
    course.rewrite(rewrite)
    contact.rewrite(rewrite)
    if var list = mixtures {
      list.rewriteEach(rewrite)
      mixtures = list
    }
    if var list = diveSites {
      list.rewrite(rewrite)
      diveSites = list
    }
    if var list = gearItems {
      list.rewrite(rewrite)
      gearItems = list
    }
    if var list = people {
      list.rewritePeople(rewrite)
      people = list
    }
  }
}
