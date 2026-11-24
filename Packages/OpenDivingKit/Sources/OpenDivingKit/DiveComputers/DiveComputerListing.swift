import Foundation

/// What a walk counted before it read a dive: the computer's dives and the ones this download
/// takes.
public struct DiveComputerListing: Hashable, Sendable {
  /// One entry the walk will download, in the order it downloads them.
  public struct Download: Hashable, Sendable {
    /// The fingerprint its dive, or its skip, is yielded with.
    public let fingerprint: Data
    /// What the computer's index or summary said of the dive before the download.
    public let facts: ListedDiveFacts

    public init(fingerprint: Data, facts: ListedDiveFacts) {
      self.fingerprint = fingerprint
      self.facts = facts
    }

    public init(fingerprint: Data, length: TimeInterval?) {
      self.init(fingerprint: fingerprint, facts: ListedDiveFacts(length: length))
    }

    /// How long the dive lasted, in seconds; nil where the list did not say.
    public var length: TimeInterval? { facts.length }
  }

  /// The engine's answer to a walk's list, before the walk's first transfer.
  public struct Decision: Hashable, Sendable {
    /// The fingerprints of the entries the walk would take that it leaves out at their place:
    /// those the logbook holds, and those the diver did not choose.
    public let leftOut: Set<Data>
    /// Of ``leftOut``, the fingerprints of the dives the logbook holds without the computer's
    /// original download that the walk takes all the same, after the rest, newest first.
    public let catchUp: Set<Data>

    public init(leftOut: Set<Data>, catchUp: Set<Data> = []) {
      self.leftOut = leftOut
      self.catchUp = catchUp
    }
  }

  /// Asks the engine about a walk's list: the entries the walk would take, newest first.
  public typealias Decide = @Sendable (DiveComputerIdentity, _ takes: [Download]) async -> Decision

  /// The dives on the computer.
  public let dives: Int
  /// The dives this download takes: those walked before the stored fingerprint's entry, or every
  /// one where none was set, less those the phone need not take again, those the logbook holds
  /// and those the diver did not choose; then the ones counted in ``catchUp``.
  public let newDives: Int
  /// Of ``newDives``, those the logbook holds without the computer's original download, taken
  /// after the rest.
  public let catchUp: Int
  /// For the Nautic family, what each listed entry's summary said of its sport, for the record
  /// to keep (``DiveComputerRecord/nauticSports``); nil for a family whose entries are all dives.
  public let sports: [NauticEntrySport]?
  /// The counted entries the walk downloads, newest first but those of ``catchUp``, which come
  /// last, each with what the list said of it, which the walk's time left is reckoned over. Empty
  /// for a family that does not say.
  public let downloads: [Download]

  public init(
    dives: Int, newDives: Int, catchUp: Int = 0, sports: [NauticEntrySport]? = nil,
    downloads: [Download] = []
  ) {
    self.dives = dives
    self.newDives = newDives
    self.catchUp = catchUp
    self.sports = sports
    self.downloads = downloads
  }

  /// This listing with `catchUp` taken after its downloads.
  public func takingAfter(_ catchUp: [Download]) -> DiveComputerListing {
    guard !catchUp.isEmpty else { return self }
    return DiveComputerListing(
      dives: dives, newDives: newDives + catchUp.count, catchUp: self.catchUp + catchUp.count,
      sports: sports, downloads: downloads + catchUp)
  }
}
