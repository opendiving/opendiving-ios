import Foundation

/// One species from the catalog, as `GET /species/{uuid}` serves it, with its photo's credit
/// as the parts the client composes.
public struct SpeciesRead: Codable, Hashable, Sendable, Identifiable {
  public var id: UUID { uuid }

  public let uuid: UUID
  /// The species' WoRMS AphiaID.
  public let aphiaId: Int
  public let scientificName: String
  public let commonName: String?
  public let authority: String?
  public let rank: String
  /// WoRMS' taxonomic status, `accepted` most often.
  public let status: String
  public let kingdom: String?
  public let phylum: String?
  public let className: String?
  public let orderName: String?
  public let family: String?
  public let genus: String?
  public let isMarine: Bool?
  public let isBrackish: Bool?
  public let isFreshwater: Bool?
  public let wikidataQid: String?
  /// Null means no photo; otherwise the `?v=` of `GET /species/{uuid}/photo`.
  public let photoSha256: String?
  /// The Commons file the photo is.
  public let photoFile: String?
  /// Plain text, which the API parses out of Commons' HTML `Artist`; never markup.
  public let photoAuthor: String?
  public let photoLicense: String?
  public let photoLicenseUrl: String?
  /// The Commons file description page: the source the licence asks to be linked.
  public let photoSourceUrl: String?
  public let createdAt: DiveTimestamp
}
