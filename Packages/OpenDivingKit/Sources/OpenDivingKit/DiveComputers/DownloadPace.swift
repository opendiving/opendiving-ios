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

  /// A Nautic-family computer's pace before the phone has timed a dive from it: an Ocean dive's
  /// original is about 340 bytes for each second of the dive, and the watch sends about 6,700
  /// bytes a second, measured on an Ocean: about three minutes for an hour of diving. No other
  /// family has one, so a Shearwater shows no estimate until the phone has timed a dive from it.
  static let nauticFirst = DownloadPace(perDiveSecond: 0.05)

  /// The pace a download from a computer of `family` is reckoned at before it starts: `kept`,
  /// the computer's own, else the family's first.
  static func before(_ family: DiveComputerFamily, kept: DownloadPace?) -> DownloadPace? {
    kept ?? (family == .suuntoNautic ? nauticFirst : nil)
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
