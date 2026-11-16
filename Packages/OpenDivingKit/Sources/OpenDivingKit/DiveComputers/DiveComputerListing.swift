import Foundation

/// What a walk counted before it read a dive: the computer's dives and the new ones this download
/// takes.
public struct DiveComputerListing: Hashable, Sendable {
  /// One entry the walk will download, in the order it downloads them.
  public struct Download: Hashable, Sendable {
    /// The fingerprint its dive, or its skip, is yielded with.
    public let fingerprint: Data
    /// How long the dive lasted, in seconds, as the computer's index or summary gave it before the
    /// download; nil where neither did.
    public let length: TimeInterval?

    public init(fingerprint: Data, length: TimeInterval?) {
      self.fingerprint = fingerprint
      self.length = length
    }
  }

  /// The dives on the computer.
  public let dives: Int
  /// The dives this download takes: those walked before the stored fingerprint's entry, or every
  /// one where none was set, less those the phone need not take again.
  public let newDives: Int
  /// For the Nautic family, what each listed entry's summary said of its sport, for the record
  /// to keep (``DiveComputerRecord/nauticSports``); nil for a family whose entries are all dives.
  public let sports: [NauticEntrySport]?
  /// The entries the walk downloads, newest first, which the walk's time left is reckoned over.
  /// Empty for a family that does not say.
  public let downloads: [Download]

  public init(
    dives: Int, newDives: Int, sports: [NauticEntrySport]? = nil, downloads: [Download] = []
  ) {
    self.dives = dives
    self.newDives = newDives
    self.sports = sports
    self.downloads = downloads
  }
}
