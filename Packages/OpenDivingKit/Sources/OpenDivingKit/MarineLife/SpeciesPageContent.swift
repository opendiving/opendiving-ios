import Foundation

/// What a species' page shows, as the web's shows it: its names and the diver's figures in the
/// hero, the photo's credit, the words of its list of dives, and its taxonomy.
public struct SpeciesPageContent: Hashable, Sendable {
  /// One row of the *Taxonomy* card.
  public struct Row: Hashable, Sendable {
    public var label: String
    public var value: String
  }

  public var hero: HeroContent
  /// Nil with no photo, and with a photo nothing was recorded beside.
  public var photoCredit: PhotoCreditContent?
  public var dives: RecordDivesContent
  /// Each rank the catalog records, then the authority.
  public var taxonomy: [Row]
  /// The identity the catalog is keyed on, opening WoRMS' own page for it.
  public var aphiaID: String
  public var aphiaURL: URL?

  public init(_ page: SpeciesPage) {
    let species = page.species
    let name = SpeciesNames.displayName(
      scientificName: species.scientificName, commonName: species.commonName)
    var facts: [Fact] = []
    // Nothing where the title already is the scientific name.
    if species.commonName != nil { facts.append(Fact(text: species.scientificName)) }
    if let rank = SpeciesNames.rankLabel(species.rank) { facts.append(Fact(text: rank)) }
    hero = HeroContent(title: name, facts: facts, figures: Self.figures(page.history))
    photoCredit = .species(species)
    dives = .species(name)
    let ranks: [(String, String?)] = [
      ("Kingdom", species.kingdom), ("Phylum", species.phylum), ("Class", species.className),
      ("Order", species.orderName), ("Family", species.family), ("Genus", species.genus),
      ("Authority", species.authority),
    ]
    taxonomy = ranks.compactMap { label, value in
      guard let value, !value.isEmpty else { return nil }
      return Row(label: label, value: value)
    }
    aphiaID = String(species.aphiaId)
    aphiaURL = URL(
      string: "https://www.marinespecies.org/aphia.php?p=taxdetails&id=\(species.aphiaId)")
  }

  /// Zeroes for a species none of the diver's dives records, as the API's 404 says; nothing
  /// where the history could not be read, rather than zeroes the page cannot vouch for.
  static func figures(_ history: SpeciesPage.History) -> [Figure] {
    switch history {
    case .seen(let entry):
      [
        Figure(label: "Dives", value: String(entry.diveCount)),
        Figure(label: "Dive sites", value: String(entry.diveSiteCount)),
        Figure(label: "Last seen", value: DateText.diveDate(entry.lastSeen)),
      ]
    case .never:
      [Figure(label: "Dives", value: "0"), Figure(label: "Dive sites", value: "0")]
    case .unknown:
      []
    }
  }

  /// The taxonomy's credit: WoRMS' text is CC BY, which asks to be credited where it is shown.
  public static let taxonomyCredit = PhotoCreditContent(runs: [
    .init("Taxonomy: "),
    .init("World Register of Marine Species", url: URL(string: "https://www.marinespecies.org")),
    .init(", "),
    .init("CC BY", url: URL(string: "https://creativecommons.org/licenses/by/4.0/")),
  ])
}
