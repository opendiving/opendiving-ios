/// What a walk counted before it read a dive: the computer's dives, the new ones this download
/// takes, and the entries it will walk to take them.
public struct DiveComputerListing: Hashable, Sendable {
  /// The dives on the computer.
  public let dives: Int
  /// The dives this download takes: those newer than the stored fingerprint, or every one where
  /// none was set.
  public let newDives: Int
  /// The new entries the walk will walk, a watch's runs among them: the bar's denominator.
  public let newEntries: Int
  /// For the Nautic family, what each listed entry's summary said of its sport, for the record
  /// to keep (``DiveComputerRecord/nauticSports``); nil for a family whose entries are all dives.
  public let sports: [NauticEntrySport]?

  public init(dives: Int, newDives: Int, newEntries: Int, sports: [NauticEntrySport]? = nil) {
    self.dives = dives
    self.newDives = newDives
    self.newEntries = newEntries
    self.sports = sports
  }
}
