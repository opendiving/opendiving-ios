import Foundation

/// One species in the diver's life list, as `GET /user/species` serves it.
public struct SpeciesLifeListEntry: Codable, Hashable, Sendable, Identifiable {
  public var id: UUID { uuid }

  public let uuid: UUID
  public let scientificName: String
  public let commonName: String?
  public let rank: String
  /// Null means no photo and no request; otherwise the `?v=` of `GET /species/{uuid}/photo`.
  public let photoSha256: String?
  public let diveCount: Int
  public let diveSiteCount: Int
  /// The start of the first and the last dive it was seen on, in any of the four spellings.
  public let firstSeen: DiveTimestamp
  public let lastSeen: DiveTimestamp
}
