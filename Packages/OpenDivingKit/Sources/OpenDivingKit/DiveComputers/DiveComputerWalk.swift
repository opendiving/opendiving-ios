import Foundation
import Observation

/// One walk over a dive computer as it stands: connecting → the dives to download, only in a
/// walk the diver started and only where it asks → downloading → the time-zone question, only in
/// a walk the diver started and only where it is needed → finished, with an outcome. ``DiveComputerEngine`` runs it; the screen draws the walk it started, or the one a
/// connection started while it runs.
@MainActor
@Observable
public final class DiveComputerWalk: Identifiable {
  public enum Phase: Hashable, Sendable {
    case connecting, choosingDives, downloading, askingTimeZone, finished
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
      /// The walk read the whole computer, and the logbook holds every dive it lists.
      case inLogbook
    }

    public let kind: Kind
    public let sentence: String

    /// *Choose dives to download* is offered, or for a computer whose family lists nothing,
    /// *Download all dives*.
    public var offersChoosing: Bool {
      kind == .nothingNew || kind == .alreadyWaiting || kind == .notDownloaded
    }
  }

  public nonisolated let id = UUID()
  public let computer: FoundComputer
  /// The diver started it from the screen and is watching: it may ask the time-zone question,
  /// and waits on a busy computer or a lost link for as long as the diver does.
  public let watched: Bool
  /// *Choose dives to download*, whose walk shows the list, or for a family that lists nothing
  /// before reading it *Download all dives*: either way the fingerprint is set aside.
  public let choosing: Bool
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
  /// The dives the walk will still take, in the order it takes them, each with what the
  /// computer's list said of it: the listing's, each leaving as it is read or passed over. Empty
  /// before a listing, for a family that lists nothing, and once the walk has ended.
  public internal(set) var queue: [DiveComputerListing.Download] = []
  /// The computer last said it was busy with another app.
  public internal(set) var computerBusy = false
  /// Another app's handshake broke a transfer since the walk started or last delivered a dive.
  public internal(set) var otherAppHandshaking = false
  /// The computer dropped the link, and the walk waits for it to come back.
  public internal(set) var linkLost = false
  /// The listing counts from the stored fingerprint, rather than the whole computer.
  public internal(set) var listedFromFingerprint = false
  public internal(set) var outcome: Outcome?
  /// What the walk asks the diver before its first transfer, while ``phase`` is
  /// ``Phase/choosingDives``.
  public internal(set) var choice: DownloadChoice?
  /// The diver answered *Only future dives*.
  var choseNone = false
  /// The server said the logbook holds every dive the walk would otherwise have taken, and the
  /// walk passed over none as answered for or not chosen.
  var logbookHoldsAll = false
  /// The diver or a change of session cancelled the walk.
  var cancelled = false
  /// The zone the time-zone question offers first: the watch's where this walk reported one,
  /// else the phone's.
  public internal(set) var suggestedZone: TimeZone
  var estimate = DownloadEstimate()

  init(
    computer: FoundComputer, watched: Bool, choosing: Bool, record: String? = nil,
    zone: TimeZone
  ) {
    self.computer = computer
    self.watched = watched
    self.choosing = choosing
    self.record = record
    suggestedZone = zone
  }

  /// A walk is in flight: from connecting to the time-zone question's answer.
  public var isBusy: Bool { phase != .finished }

  /// The dive of ``queue`` being read now, its first, while the walk downloads.
  public var inTransfer: DiveComputerListing.Download? {
    phase == .downloading ? queue.first : nil
  }

  /// The uuid a dive of the queue is imported under, once the computer identified itself.
  public func diveUUID(_ dive: DiveComputerListing.Download) -> UUID? {
    identity.map { DiveComputerArchive.diveUUID($0, fingerprint: dive.fingerprint) }
  }

  /// The listed entry `fingerprint` was read or passed over.
  func took(_ fingerprint: Data) {
    if let index = queue.firstIndex(where: { $0.fingerprint == fingerprint }) {
      queue.remove(at: index)
    }
  }

  /// *Downloading 2 of 3 new dives* after a listing, *Downloading dive 3* without one.
  public var downloadingText: String {
    guard let listing else { return DiveComputerText.downloading(max(1, divesDownloaded + 1)) }
    return DiveComputerText.downloading(
      min(divesDownloaded + 1, max(1, listing.newDives)), of: listing.newDives)
  }

  /// While connecting: *Connecting* until the computer is identified, then *Reading* until the
  /// download starts.
  public var connectingText: String? {
    guard phase == .connecting else { return nil }
    return identity == nil ? DiveComputerText.connecting : DiveComputerText.reading
  }

  /// While connecting or downloading: *The connection to this computer was lost…* while the walk
  /// waits for a lost link; else *This computer is busy…* from a computer that is: closing other
  /// apps lets the download go on, once another app's handshake broke a transfer and until a dive
  /// arrives; else, while the computer says it is busy, the download starts when it is free, or
  /// once a dive has downloaded, continues.
  public var waitingText: String? {
    guard phase == .connecting || phase == .downloading else { return nil }
    if linkLost { return DiveComputerText.linkLost }
    if otherAppHandshaking { return DiveComputerText.busyOtherApp }
    guard computerBusy else { return nil }
    return divesDownloaded > 0 ? DiveComputerText.busyContinues : DiveComputerText.busy
  }

  /// The seconds left of the download at `date`, while it downloads and the computer is neither
  /// lost nor waiting on another app; nil where nothing yet gives an estimate.
  public func timeLeft(at date: Date) -> TimeInterval? {
    guard phase == .downloading, !linkLost, !computerBusy, !otherAppHandshaking else { return nil }
    return estimate.remaining(at: date)
  }

  /// The walk is downloading what an estimate would count down, and nothing gives one yet: the
  /// computer's first download, before its first dive has been timed.
  public func isEstimating(at date: Date) -> Bool {
    guard phase == .downloading, !linkLost, !computerBusy, !otherAppHandshaking else {
      return false
    }
    return estimate.hasLeft && estimate.remaining(at: date) == nil
  }

  /// The computer's line in the list while the walk is in flight: *Waiting for this computer to
  /// reconnect* while it waits for a lost link, *Waiting until this computer is free* while it is
  /// busy, else where the walk stands. Nil at a question and once finished.
  public var statusLine: String? {
    switch phase {
    case .connecting, .downloading:
      if linkLost { return DiveComputerText.waitingToReconnect }
      if computerBusy || otherAppHandshaking { return DiveComputerText.waitingUntilFree }
      return phase == .connecting ? DiveComputerText.connecting : downloadingText
    case .choosingDives, .askingTimeZone, .finished:
      return nil
    }
  }

  /// Whether this walk is of `record`'s computer: by its identity once it gave one, else by the
  /// record a connection started it for or the Core Bluetooth identifier it opens.
  public func isOf(_ record: DiveComputerRecord) -> Bool {
    if let identity { return DiveComputerRecord(identity: identity).id == record.id }
    if let started = self.record { return started == record.id }
    return computer.id == record.peripheral
  }
}
