import Foundation

/// A row of `GET /dive-sites/suggest`: a named dive site from the catalog the server ships,
/// to prefill a new site from. Sending its `externalId` in the new site's `external_ids` keeps
/// the record's registry entry.
public struct DiveSiteSuggestion: Codable, Hashable, Sendable {
  public let name: String
  public let nameEn: String?
  public let latitude: Double
  public let longitude: Double
  public let country: String?
  public let region: String?
  /// `osm` or `wikidata`, as the API sent it.
  public let source: String
  public let sourceId: String
  /// What the source's licence asks to be shown with the row; a client showing it renders it.
  public let attribution: String
  public let externalId: ExternalIdRead
  /// The diver's site that already carries this entry, offered instead of making a second.
  public let heldSite: DiveSiteReference?
}

/// A site of the diver's, by name.
public struct DiveSiteReference: Codable, Hashable, Sendable {
  public let uuid: UUID
  public let name: String
}

/// `GET /dive-sites/suggest`'s answer. `hasMore` means the result cap cut it: keep typing.
public struct DiveSiteSuggestResponse: Codable, Hashable, Sendable {
  public let results: [DiveSiteSuggestion]
  public let hasMore: Bool
}
