import Foundation

/// How fast one dive computer's dives came over to this phone, kept with its pairing so that a
/// download's time left can be reckoned before its first dive arrives. The link's speed is the
/// phone's and the computer's, whichever account is signed in.
public struct DownloadPace: Codable, Hashable, Sendable {
  /// Seconds of transfer per second of dive, over dives whose length the computer gave before
  /// they were downloaded: a dive's bytes grow with its length.
  public var perDiveSecond: Double?
  /// Seconds of transfer per dive, for a dive whose length is not known.
  public var perDive: Double?

  public init(perDiveSecond: Double? = nil, perDive: Double? = nil) {
    self.perDiveSecond = perDiveSecond
    self.perDive = perDive
  }

  /// This pace with a later walk's measured over it: each figure the mean of the two where both
  /// are known, so a pace follows a link that changed within a walk or two and one slow walk does
  /// not undo the others; else whichever is known.
  func merged(_ later: DownloadPace) -> DownloadPace {
    func mean(_ old: Double?, _ new: Double?) -> Double? {
      guard let new else { return old }
      return old.map { ($0 + new) / 2 } ?? new
    }
    return DownloadPace(
      perDiveSecond: mean(perDiveSecond, later.perDiveSecond), perDive: mean(perDive, later.perDive)
    )
  }

  /// This pace where it knows each figure, `fallback` where it does not.
  func over(_ fallback: DownloadPace?) -> DownloadPace {
    DownloadPace(
      perDiveSecond: perDiveSecond ?? fallback?.perDiveSecond,
      perDive: perDive ?? fallback?.perDive)
  }
}
