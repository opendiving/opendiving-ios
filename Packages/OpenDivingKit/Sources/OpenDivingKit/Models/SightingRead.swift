import Foundation

/// One species seen on a dive. `uuid` is the species' own.
public struct SightingRead: Codable, Hashable, Sendable {
  public let uuid: UUID
  public let scientificName: String
  public let commonName: String?
  /// The taxonomic rank, `Species`, `Family`, … — a sighting is not always of a species.
  public let rank: String
  /// The whole photo contract: null means no photo and no request; otherwise the `?v=` of
  /// `GET /species/{uuid}/photo`.
  public let photoSha256: String?
  /// Null is seen, not counted.
  public let count: Int?
  /// `few`, `many` or `abundant`, as the API sent it; null where a count is set.
  public let abundance: String?
  public let notes: String
}
