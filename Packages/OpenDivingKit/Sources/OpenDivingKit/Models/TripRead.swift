import Foundation

/// A trip, as `GET /trips` and `GET /trip/{uuid}` serve it.
public struct TripRead: Codable, Hashable, Sendable, Identifiable {
  public var id: UUID { uuid }

  public let uuid: UUID
  public let name: String
  public let notes: String
  /// Its booking, itinerary, shared album and the like, in the diver's order.
  public let links: [WebLink]
  public let parts: [TripPartRead]
  public let people: [PersonReference]
  public let diveCount: Int
  public let diveSiteCount: Int
  public let speciesCount: Int
  /// Metres.
  public let maxDepth: Double?
  public let candidateCount: Int
  public let contactUuids: [UUID]
  public let userUuid: UUID
  public let createdAt: DiveTimestamp

  public init(from decoder: any Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    uuid = try c.decode(UUID.self, forKey: .uuid)
    name = try c.decode(String.self, forKey: .name)
    notes = try c.decode(String.self, forKey: .notes)
    links = try c.decodeLinks(forKey: .links)
    parts = try c.decode([TripPartRead].self, forKey: .parts)
    people = try c.decode([PersonReference].self, forKey: .people)
    diveCount = try c.decode(Int.self, forKey: .diveCount)
    diveSiteCount = try c.decode(Int.self, forKey: .diveSiteCount)
    speciesCount = try c.decode(Int.self, forKey: .speciesCount)
    maxDepth = try c.decodeIfPresent(Double.self, forKey: .maxDepth)
    candidateCount = try c.decode(Int.self, forKey: .candidateCount)
    contactUuids = try c.decode([UUID].self, forKey: .contactUuids)
    userUuid = try c.decode(UUID.self, forKey: .userUuid)
    createdAt = try c.decode(DiveTimestamp.self, forKey: .createdAt)
  }
}
