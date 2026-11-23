/// What an Ocean logbook entry's summary named — its sport, how long it lasted and what it says of
/// the dive — kept so a later walk need not read that summary again.
public struct NauticEntrySport: Codable, Hashable, Sendable {
  /// The entry's id in the watch's logbook: its start, in Unix seconds.
  public let id: UInt32
  /// Suunto's activity id; nil where the summary named none, which counts as a dive.
  public let sport: Int?
  /// How long the entry lasted, in seconds; nil where the summary did not say, or the record was
  /// kept before it was read.
  public let duration: Double?
  /// The dive's start, length and depth as the summary gave them
  /// (``NauticDescriptors/facts(inSummary:id:)``); nil where the record was kept before they were
  /// read, which a dive's entry has its summary read again for.
  public let facts: ListedDiveFacts?

  public init(id: UInt32, sport: Int?, duration: Double? = nil, facts: ListedDiveFacts? = nil) {
    self.id = id
    self.sport = sport
    self.duration = duration
    self.facts = facts
  }

  /// Whether the entry counts and downloads as a dive: a diving sport, or none named.
  public var isDive: Bool { sport.map(NauticSport.diving.contains) ?? true }
}
