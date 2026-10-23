/// How a species is named on its card.
public enum SpeciesNames {
  /// The common name, or the scientific one for the many species with none.
  public static func displayName(scientificName: String, commonName: String?) -> String {
    commonName ?? scientificName
  }

  /// A taxon's rank to print, or nil for a blank one and for the API's `unknown`
  /// placeholder, which says how much is known rather than anything about the animal.
  public static func rankLabel(_ rank: String?) -> String? {
    let trimmed = rank?.trimmedOfWhitespace ?? ""
    if trimmed.isEmpty || trimmed.lowercased() == "unknown" { return nil }
    return trimmed
  }

  /// The scientific name, with the rank named when the row is broader than a species —
  /// `Muraenidae (Family)` — since a family alone reads as a species name.
  public static func scientificNameWithRank(_ scientificName: String, rank: String?) -> String {
    guard let rank = rankLabel(rank), rank.lowercased() != "species" else { return scientificName }
    return "\(scientificName) (\(rank))"
  }
}
