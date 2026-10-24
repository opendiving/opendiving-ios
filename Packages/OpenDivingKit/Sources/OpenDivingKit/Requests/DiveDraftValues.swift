import Foundation

/// A dive draft's `values`: every member of ``DiveCreate``, each optional, the lists among them.
/// A draft is a dive not yet logged, so nothing is required and nothing is checked across
/// members; the server refuses only a wrong type or a word outside a vocabulary. A member left
/// nil is not sent, and the server keeps no member a write leaves out.
public struct DiveDraftValues: Codable, Hashable, Sendable {
  public var diveNumber: Int?
  public var startTime: DiveTimestamp?
  public var submergedTime: Int?
  public var maxDepth: Double?
  public var avgDepth: Double?
  public var bottomTemperature: Double?
  public var visibility: Int?
  public var weight: Double?
  public var waterType: String?
  public var altitude: Int?
  public var type: String?
  public var rating: Int?
  public var airTemperature: Double?
  public var current: String?
  public var waves: String?
  public var weather: String?
  public var entryType: String?
  public var boatName: String?
  public var notes: String?
  public var trip: RecordRef?
  public var course: RecordRef?
  public var contact: RecordRef?
  public var mixtures: [DiveMixtureWrite]?
  public var diveSites: [RecordRef]?
  /// The items ticked on the gear set the draft loaded, which are the dive's gear.
  public var gearItems: [RecordRef]?
  public var sightings: [SightingWrite]?
  public var people: [PersonReference]?
  public var tags: [String]?

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

  /// A draft of nothing yet; set what the diver has filled.
  public init() {}
}

extension DiveDraftValues: RewritesLocalRefs {
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
