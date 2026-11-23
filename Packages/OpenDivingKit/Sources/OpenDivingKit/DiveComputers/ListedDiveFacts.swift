import Foundation

/// What a computer's list says of one dive before the dive is read: its start, its length and
/// its max depth, each where the list gives it. A Petrel-family computer's index record gives all
/// three; a Nautic-family entry's id is its start, and its summary the rest.
public struct ListedDiveFacts: Hashable, Sendable {
  /// When the dive started, as the list gives it.
  public enum Start: Hashable, Sendable {
    /// The computer's wall clock, for a family that logs no zone.
    case wallClock(LocalDateTime)
    /// An instant, for a family that logs one, with its offset from UTC in seconds: the one its
    /// summary logged it under, where it did, and once the dive is in an archive, the one its
    /// document was written in.
    case instant(Date, offsetSeconds: Int?)
  }

  public var start: Start?
  /// How long the dive lasted, in seconds.
  public var length: TimeInterval?
  /// In metres.
  public var maxDepth: Double?

  public init(start: Start? = nil, length: TimeInterval? = nil, maxDepth: Double? = nil) {
    self.start = start
    self.length = length
    self.maxDepth = maxDepth
  }

  /// The facts with an instant that has no offset given `zone`'s at that instant: the zone its
  /// document is written in.
  func written(in zone: TimeZone?) -> ListedDiveFacts {
    guard case .instant(let instant, nil)? = start, let zone else { return self }
    var written = self
    written.start = .instant(instant, offsetSeconds: zone.secondsFromGMT(for: instant))
    return written
  }

  /// The start as the phone writes it in the dive's document, as far as the list says: a wall
  /// clock with no offset, or the instant in its offset, else in UTC. What
  /// `POST /dive-computers/known-dives` is sent.
  public var listedStart: String? {
    switch start {
    case .wallClock(let clock): clock.iso8601
    case .instant(let instant, let offset):
      DiveComputerArchive.dateTime(
        instant, in: TimeZone(secondsFromGMT: offset ?? 0) ?? TimeZone(secondsFromGMT: 0)!)
    case nil: nil
    }
  }

  /// The start to show: a wall clock as it is, and an instant on the clock of its offset, else
  /// `watchZone`'s, else `phoneZone`'s.
  public func shownStart(watchZone: TimeZone?, phoneZone: TimeZone) -> DiveTimestamp? {
    switch start {
    case .wallClock(let clock): return .wallClock(clock)
    case .instant(let instant, let offset):
      let zone = offset.flatMap(TimeZone.init(secondsFromGMT:)) ?? watchZone ?? phoneZone
      let whole = Date(timeIntervalSince1970: instant.timeIntervalSince1970.rounded(.down))
      return .instant(
        DiveComputerArchive.clock(whole, in: zone),
        utcOffsetMinutes: zone.secondsFromGMT(for: whole) / 60)
    case nil: return nil
    }
  }
}

extension ListedDiveFacts: Codable {
  private enum CodingKeys: String, CodingKey {
    case wallClock, instant, offsetSeconds, length, maxDepth
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    if let clock = try container.decodeIfPresent(DiveTimestamp.self, forKey: .wallClock)?
      .wallClock
    {
      start = .wallClock(clock)
    } else if let instant = try container.decodeIfPresent(Date.self, forKey: .instant) {
      start = .instant(
        instant,
        offsetSeconds: try container.decodeIfPresent(Int.self, forKey: .offsetSeconds))
    }
    length = try container.decodeIfPresent(TimeInterval.self, forKey: .length)
    maxDepth = try container.decodeIfPresent(Double.self, forKey: .maxDepth)
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    switch start {
    case .wallClock(let clock):
      try container.encode(DiveTimestamp.wallClock(clock), forKey: .wallClock)
    case .instant(let instant, let offset):
      try container.encode(instant, forKey: .instant)
      try container.encodeIfPresent(offset, forKey: .offsetSeconds)
    case nil: break
    }
    try container.encodeIfPresent(length, forKey: .length)
    try container.encodeIfPresent(maxDepth, forKey: .maxDepth)
  }
}
