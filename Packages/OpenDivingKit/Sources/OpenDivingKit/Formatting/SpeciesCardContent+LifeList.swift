import Foundation

extension SpeciesCardContent {
  /// A life-list row as its card on a site's page: its names, and how many of the diver's
  /// dives it was seen on and the day of the last, on that dive's own calendar.
  public static func lifeList(_ entry: SpeciesLifeListEntry, photo: Data? = nil)
    -> SpeciesCardContent
  {
    SpeciesCardContent(
      photo: photo,
      commonName: SpeciesNames.displayName(
        scientificName: entry.scientificName, commonName: entry.commonName),
      scientificName: SpeciesNames.scientificNameWithRank(entry.scientificName, rank: entry.rank),
      figures: [
        Figure(label: "Dives", value: String(entry.diveCount)),
        Figure(label: "Last seen", value: DateText.diveDate(entry.lastSeen)),
      ])
  }
}
