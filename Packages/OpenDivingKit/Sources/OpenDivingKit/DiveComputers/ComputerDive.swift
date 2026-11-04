import Foundation

/// One dive as the shared libdivecomputer reader (`libdivejson`) returned it: a DiveJSON `dive`
/// object with one recording, which carries no device and no stored file. The Kit adds what is
/// the host's — the start's zone, the uuid, the device block and the stored file — and changes
/// nothing else in it.
public struct ComputerDive: Hashable, Sendable {
  /// When the dive started, as the reader reported it.
  public enum Start: Hashable, Sendable {
    /// The computer's wall clock, with its offset from UTC in seconds where the parser
    /// reported a zone. The Shearwater family logs a wall clock with no zone.
    case wallClock(LocalDateTime, utcOffsetSeconds: Int?)
    /// An instant with no local clock: the Suunto Nautic family's, which the writer resolves
    /// in the zone of the dive's position, else one the watch or the diver supplies.
    case instant(Date)
  }

  public let start: Start
  /// The start the reader was given for a dive whose bytes may state none, which the stored
  /// file's tag carries so the server re-reads the bytes with it.
  public let fallbackStart: Date?
  let body: [String: ArchiveJSON]

  /// The reader's dive, from its JSON; nil where that is not a dive object with a start and one
  /// recording. `logsInstants` says the family's start is an instant, which the reader spells
  /// with the parser's offset, `+00:00` for the Suunto Nautic family.
  public init?(json: Data, logsInstants: Bool, fallbackStart: Date?) {
    guard case .object(let body)? = ArchiveJSON.parse(json),
      let recordings = body["recordings"]?.arrayValue, recordings.count == 1,
      case .object? = recordings.first,
      let text = body["started_at"]?.stringValue,
      let start = Self.start(text, logsInstants: logsInstants)
    else { return nil }
    self.start = start
    self.fallbackStart = fallbackStart
    self.body = body
  }

  /// No samples and no duration over a second: not a dive. On the Nautic family, an empty or
  /// aborted session.
  public var isEmpty: Bool {
    body["recordings"]?.arrayValue?.first?["profile"] == nil
      && (body["submerged_time"]?.integerValue ?? 0) <= 1
  }

  /// Where the dive went in, in decimal degrees: the computer's first GPS fix, where it has one.
  public var entryPosition: (latitude: Double, longitude: Double)? {
    guard let position = body["entry_position"],
      let latitude = position["latitude"]?.numberValue,
      let longitude = position["longitude"]?.numberValue
    else { return nil }
    return (latitude, longitude)
  }

  /// An instant as the reader and the server take a fallback start: RFC 3339 in UTC.
  public static func instantText(_ instant: Date) -> String {
    DiveComputerArchive.dateTime(instant, in: TimeZone(secondsFromGMT: 0)!)
  }

  private static func start(_ text: String, logsInstants: Bool) -> Start? {
    let stamp = DiveTimestamp(wireValue: text)
    if logsInstants, let instant = stamp?.instant { return .instant(instant) }
    switch stamp {
    case .instant(let clock, let minutes)?:
      return .wallClock(clock, utcOffsetSeconds: minutes * 60)
    case .wallClock(let clock)?:
      return .wallClock(clock, utcOffsetSeconds: nil)
    case .day?, nil:
      return nil
    }
  }
}
