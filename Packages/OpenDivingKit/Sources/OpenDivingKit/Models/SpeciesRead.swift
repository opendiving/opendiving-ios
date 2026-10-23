import Foundation

/// One species from the catalog, as `GET /species/{uuid}` serves it, with its photo's credit
/// as the parts the client composes.
public struct SpeciesRead: Codable, Hashable, Sendable {
  public let uuid: UUID
  public let scientificName: String
  public let commonName: String?
  public let rank: String
  /// Null means no photo; otherwise the `?v=` of `GET /species/{uuid}/photo`.
  public let photoSha256: String?
  /// Plain text, which the API parses out of Commons' HTML `Artist`; never markup.
  public let photoAuthor: String?
  public let photoLicense: String?
  public let photoLicenseUrl: String?
  /// The Commons file description page: the source the licence asks to be linked.
  public let photoSourceUrl: String?
}
