/// What a walk counted before it read a dive: the computer's dives and the new ones this download
/// takes.
public struct DiveComputerListing: Hashable, Sendable {
  /// The dives on the computer.
  public let dives: Int
  /// The dives this download takes: those walked before the stored fingerprint's entry, or every
  /// one where none was set, less those the phone need not take again.
  public let newDives: Int
  /// For the Nautic family, what each listed entry's summary said of its sport, for the record
  /// to keep (``DiveComputerRecord/nauticSports``); nil for a family whose entries are all dives.
  public let sports: [NauticEntrySport]?

  public init(dives: Int, newDives: Int, sports: [NauticEntrySport]? = nil) {
    self.dives = dives
    self.newDives = newDives
    self.sports = sports
  }
}
