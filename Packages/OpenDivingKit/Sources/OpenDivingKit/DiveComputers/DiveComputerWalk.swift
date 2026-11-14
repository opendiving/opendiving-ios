import Foundation
import Observation

/// One walk over a dive computer as it stands: connecting → downloading → the time-zone
/// question, only in a walk the diver started and only where it is needed → finished, with an
/// outcome. ``DiveComputerEngine`` runs it; the screen draws the walk it started.
@MainActor
@Observable
public final class DiveComputerWalk: Identifiable {
  public enum Phase: Hashable, Sendable {
    case connecting, downloading, askingTimeZone, finished
  }

  /// How the walk ended.
  public struct Outcome: Hashable, Sendable {
    public enum Kind: Hashable, Sendable {
      /// The dives are kept on the phone, to be imported.
      case kept
      /// The walk stopped at the stored fingerprint with no dive delivered.
      case nothingNew
      /// Every new dive was downloaded before and waits on the phone to be imported.
      case alreadyWaiting
      /// The walk completed, delivering no dive, and left out entries whose download kept
      /// failing.
      case notDownloaded
      case noDives
      case cancelled
      case failed
      /// Downloaded, and kept nowhere.
      case notKept
      /// The computer that answered is not one the phone paired, and was closed unread.
      case unpaired
    }

    public let kind: Kind
    public let sentence: String

    /// *Download all dives* is offered.
    public var offersDownloadAll: Bool {
      kind == .nothingNew || kind == .alreadyWaiting || kind == .notDownloaded
    }
  }

  public nonisolated let id = UUID()
  public let computer: FoundComputer
  /// The diver started it from the screen and is watching: it may ask the time-zone question,
  /// and waits on a busy computer for as long as the diver does.
  public let watched: Bool
  /// *Download all dives*: no fingerprint is set.
  public let all: Bool
  /// The paired record a connection started it for; nil for the diver's.
  let record: String?

  public internal(set) var phase = Phase.connecting
  /// The computer being downloaded, once it identified itself.
  public internal(set) var identity: DiveComputerIdentity?
  public internal(set) var divesDownloaded = 0
  /// libdivecomputer's progress up to 1, where the family reports it; else, after a listing, the
  /// dives downloaded over the new dives the listing named. Never below ``startingProgress``.
  public var progress: Double? { walkProgress.map { max(Self.startingProgress, $0) } }
  /// The least of the bar, so a long first dive does not read as a download that has not begun.
  public static let startingProgress = 0.05
  var walkProgress: Double?
  /// The walk's count, once the computer listed its entries.
  public internal(set) var listing: DiveComputerListing?
  /// The computer last said it was busy with another app.
  public internal(set) var computerBusy = false
  /// Another app's handshake broke a transfer since the walk started or last delivered a dive.
  public internal(set) var otherAppHandshaking = false
  /// The listing counts from the stored fingerprint, rather than the whole computer.
  public internal(set) var listedFromFingerprint = false
  public internal(set) var outcome: Outcome?
  /// The zone the time-zone question offers first: the watch's where this walk reported one,
  /// else the phone's.
  public internal(set) var suggestedZone: TimeZone

  init(
    computer: FoundComputer, watched: Bool, all: Bool, record: String? = nil, zone: TimeZone
  ) {
    self.computer = computer
    self.watched = watched
    self.all = all
    self.record = record
    suggestedZone = zone
  }

  /// A walk is in flight: from connecting to the time-zone question's answer.
  public var isBusy: Bool { phase != .finished }
}
