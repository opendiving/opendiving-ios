import Foundation

/// A trip, as `GET /trips` and `GET /trip/{uuid}` serve it.
public struct TripRead: Codable, Hashable, Sendable, Identifiable {
  public var id: UUID { uuid }

  public let uuid: UUID
  public let name: String
  public let notes: String
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
}
