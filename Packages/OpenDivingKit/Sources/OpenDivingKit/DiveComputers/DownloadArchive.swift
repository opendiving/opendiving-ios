import Foundation

/// One walk's dives as one archive on the phone, waiting to be imported: the only copy of them
/// until the server has answered for it.
public struct DownloadArchive: Codable, Hashable, Sendable, Identifiable {
  /// Why the archive is not sent again by itself.
  public enum Refusal: Codable, Hashable, Sendable {
    /// The server refused it, in its own sentence where it gave one.
    case server(message: String?)
    /// The server answered with a pending import: it cannot apply an import in one request.
    case notAppliedAtOnce
  }

  public let id: UUID
  /// The upload's `Idempotency-Key`, one for these files however often they are sent: a repeat
  /// answers the import the first attempt made.
  public let key: UUID
  public let filename: String
  public let summary: DownloadSummary
  /// The record of the computer it came from, ``DiveComputerRecord/id``.
  public let record: String
  /// The dives it holds, by their derived uuids.
  public let dives: [UUID]
  /// Kept while signed in before the account had loaded, under the last account: it moves if
  /// the load names another.
  public var receivedBeforeAccountKnown: Bool
  public var refusal: Refusal?
  /// The diver has been told the dives were downloaded and wait — for a route or a sign-in.
  public var announced: Bool

  init(
    id: UUID = UUID(), key: UUID = UUID(), filename: String, summary: DownloadSummary,
    record: String, dives: [UUID], receivedBeforeAccountKnown: Bool, refusal: Refusal? = nil,
    announced: Bool = false
  ) {
    self.id = id
    self.key = key
    self.filename = filename
    self.summary = summary
    self.record = record
    self.dives = dives
    self.receivedBeforeAccountKnown = receivedBeforeAccountKnown
    self.refusal = refusal
    self.announced = announced
  }
}

/// A walk's dives as they arrive, kept until they become an archive: a walk under way, one an
/// ended process left behind, or dives that wait for the diver's time zone.
struct KeptWalk: Codable, Hashable, Sendable, Identifiable {
  let id: UUID
  /// The computer's record, once the walk identified it.
  var record: String?
  /// The zone the watch reported, by identifier, and its offset where the identifier does not
  /// name a zone this platform knows.
  var watchZone: String?
  var watchZoneSeconds: Int?
  var receivedBeforeAccountKnown: Bool
  /// When the walk began: its dives' moment in the archive's names.
  var startedAt: Date
  /// The dives wait for the diver's answer to the time-zone question.
  var heldForZone: Bool
  /// The diver has been told they wait.
  var announced: Bool
  var dives: [KeptDive]

  var zone: TimeZone? {
    get {
      watchZone.flatMap(TimeZone.init(identifier:))
        ?? watchZoneSeconds.flatMap(TimeZone.init(secondsFromGMT:))
    }
    set {
      watchZone = newValue?.identifier
      watchZoneSeconds = newValue?.secondsFromGMT()
    }
  }
}
