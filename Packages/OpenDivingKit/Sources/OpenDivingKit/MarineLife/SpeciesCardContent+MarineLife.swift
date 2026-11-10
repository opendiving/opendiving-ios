import Foundation

extension SpeciesCardContent {
  /// A life-list row as More's *Marine Life* draws it: its names, how many of the diver's dives
  /// and sites it was seen on, and the day of the last sighting, on that dive's own calendar.
  public static func marineLife(_ entry: SpeciesLifeListEntry, photo: Data? = nil)
    -> SpeciesCardContent
  {
    var card = lifeList(entry, photo: photo)
    card.figures = [
      Figure(label: "Dives", value: String(entry.diveCount)),
      Figure(label: "Dive sites", value: String(entry.diveSiteCount)),
      Figure(label: "Last seen", value: DateText.diveDate(entry.lastSeen)),
    ]
    return card
  }
}
