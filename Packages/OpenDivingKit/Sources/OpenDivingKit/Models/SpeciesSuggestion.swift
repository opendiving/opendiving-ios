import Foundation

/// A row of `GET /user/species/suggest`: a species the diver logged at the dive's sites, then
/// elsewhere, then from the catalog search. One with no `uuid` is a register hit that
/// `POST /species/resolve` turns into a catalog species before a dive can name it.
public struct SpeciesSuggestion: Codable, Hashable, Sendable {
  public let aphiaId: Int
  public let uuid: UUID?
  public let scientificName: String
  public let commonName: String?
  public let rank: String
  public let status: String
  /// The alias or synonym that matched, where the row's own names do not explain the match.
  public let matchedName: String?
  /// `catalog`, `worms` or `wikidata`, as the API sent it.
  public let source: String
  /// What the source's licence asks to be shown with the row.
  public let attribution: String
  /// The diver's dives at the request's sites that logged it.
  public let diveCountAtSites: Int
  public let lastSeen: DiveTimestamp?
}

/// `GET /user/species/suggest`'s answer. `hasMore` means the page was cut: keep typing.
public struct SpeciesSuggestResponse: Codable, Hashable, Sendable {
  public let results: [SpeciesSuggestion]
  public let hasMore: Bool
}
