/// The sport an Ocean logbook entry's summary named, kept so a later walk need not read that
/// summary again.
public struct NauticEntrySport: Codable, Hashable, Sendable {
  /// The entry's id in the watch's logbook: its start, in Unix seconds.
  public let id: UInt32
  /// Suunto's activity id; nil where the summary named none, which counts as a dive.
  public let sport: Int?

  public init(id: UInt32, sport: Int?) {
    self.id = id
    self.sport = sport
  }

  /// Whether the entry counts and downloads as a dive: a diving sport, or none named.
  public var isDive: Bool { sport.map(NauticSport.diving.contains) ?? true }
}
