import Foundation
import OpenDivingKit

/// A link that replays scripted downloads: the scan finds what the test lists, and each
/// download yields its script's events, calling the lookup as a conformance does once the
/// identity is known and recording what it answered, and keeping each dive before it yields it.
/// At a listing it asks `leaveOut` about the listing's downloads and waits for the answer, then
/// yields the listing without what was left out, each such dive as skipped and the end counting
/// them as waiting. Asked for only a paired computer, it ends a script whose identity has no
/// record there, unpaired.
@MainActor
final class FakeDiveComputerLink: DiveComputerLink {
  var state = DiveComputerAvailability.on
  var found: [FoundComputer] = []
  /// One script per download, in order; the last repeats.
  var scripts: [[DiveComputerDownloadEvent]] = []
  /// Held before the script's last event until ``release()``.
  var holdBeforeEnd = false
  /// Held before the script's event at this index until ``release()``; may be moved on while
  /// held.
  var holdBefore: Int?
  private(set) var downloads = 0
  private(set) var fingerprintsSet: [Data?] = []
  /// The entries' sports the record `lookup` returned remembered, for each download.
  private(set) var sportsRemembered: [[NauticEntrySport]?] = []
  /// The test of a dive the phone need not take again each download was handed.
  private(set) var waitingTests: [@Sendable (DiveComputerIdentity, Data) -> Bool] = []
  /// What each listing asked `leaveOut` about, and what it answered, in order.
  private(set) var asked: [[DiveComputerListing.Download]] = []
  private(set) var leftOut: [Set<Data>] = []
  /// The computer each download opened, whether it asked for a paired one only, and whether it
  /// waits for a lost link.
  private(set) var opened: [(computer: FoundComputer, pairedOnly: Bool, waitsForLink: Bool)] = []
  /// Each foreground state the engine handed over, in order.
  private(set) var foregrounds: [Bool] = []
  /// How often the engine said the computer a walk waits for is back.
  private(set) var returns = 0
  /// A cancel reached some download.
  private(set) var cancelled = false
  /// The downloads, by index, a cancel reached.
  private var cancelledDownloads: Set<Int> = []
  private var held: CheckedContinuation<Void, Never>?
  /// Tests waiting, through ``untilHeld()``, for the next hold.
  private var holdWaiters: [CheckedContinuation<Void, Never>] = []
  /// A release that came before the download in flight reached its hold, which it then passes.
  private var releasedEarly = false

  func availability() -> AsyncStream<DiveComputerAvailability> {
    AsyncStream {
      $0.yield(state)
      $0.finish()
    }
  }

  /// How many scans were started.
  private(set) var scans = 0

  func scan() -> AsyncStream<FoundComputer> {
    scans += 1
    let found = found
    return AsyncStream { continuation in
      for computer in found { continuation.yield(computer) }
      continuation.finish()
    }
  }

  func download(
    _ computer: FoundComputer, pairedOnly: Bool, waitsForLink: Bool,
    lookup: @escaping @Sendable (DiveComputerFamily, String) -> DiveComputerRecord?,
    waiting: @escaping @Sendable (DiveComputerIdentity, Data) -> Bool,
    leaveOut: @escaping @Sendable (DiveComputerIdentity, [DiveComputerListing.Download]) async ->
      Set<Data>,
    keep: @escaping @Sendable (DownloadedDive) -> Void
  ) -> AsyncStream<DiveComputerDownloadEvent> {
    let script = scripts.isEmpty ? [] : scripts[min(downloads, scripts.count - 1)]
    let download = downloads
    downloads += 1
    releasedEarly = false
    waitingTests.append(waiting)
    opened.append((computer, pairedOnly, waitsForLink))
    let (stream, continuation) = AsyncStream.makeStream(of: DiveComputerDownloadEvent.self)
    Task {
      var identity: DiveComputerIdentity?
      var logbook: Set<Data> = []
      for (index, scripted) in script.enumerated() {
        var event = scripted
        if case .identified(let identity) = event {
          let record = lookup(identity.family, identity.serial.lowercased())
          fingerprintsSet.append(record?.fingerprint)
          sportsRemembered.append(record?.nauticSports)
          if pairedOnly, record == nil {
            continuation.yield(event)
            continuation.yield(.finished(.init(.unpaired)))
            continuation.finish()
            return
          }
        }
        if index == script.count - 1 && holdBeforeEnd || index == holdBefore {
          if releasedEarly {
            releasedEarly = false
          } else {
            await withCheckedContinuation {
              held = $0
              let waiters = holdWaiters
              holdWaiters = []
              for waiter in waiters { waiter.resume() }
            }
          }
        }
        if case .identified(let found) = event { identity = found }
        if case .listing(let listing) = event, let identity, !listing.downloads.isEmpty {
          asked.append(listing.downloads)
          logbook = await leaveOut(identity, listing.downloads)
          leftOut.append(logbook)
          let downloads = listing.downloads.filter { !logbook.contains($0.fingerprint) }
          event = .listing(
            DiveComputerListing(
              dives: listing.dives,
              newDives: listing.newDives - (listing.downloads.count - downloads.count),
              sports: listing.sports, downloads: downloads))
        }
        if case .dive(let dive) = event, logbook.contains(dive.fingerprint) {
          event = .skipped(fingerprint: dive.fingerprint)
        }
        if case .finished(let end) = event, !logbook.isEmpty {
          event = .finished(
            DiveComputerDownloadEnd(
              end.kind, emptyReads: end.emptyReads, refused: end.refused,
              waiting: end.waiting + logbook.count, notDownloaded: end.notDownloaded))
        }
        if case .finished = event, cancelledDownloads.contains(download) {
          continuation.yield(.finished(.init(.cancelled)))
        } else {
          if case .dive(let dive) = event { keep(dive) }
          continuation.yield(event)
        }
        await Task.yield()
      }
      continuation.finish()
    }
    return stream
  }

  func computer(for record: DiveComputerRecord, at peripheral: UUID) -> FoundComputer {
    FoundComputer(
      id: peripheral, name: record.product, family: record.family, vendor: record.vendor,
      product: record.product)
  }

  /// Lets the held download go on; sent before it holds, it lets the next hold pass, so a test
  /// that waited on what the download yielded rather than on the hold never leaves it standing.
  func release() {
    guard let held else {
      releasedEarly = true
      return
    }
    held.resume()
    self.held = nil
  }

  var isHeld: Bool { held != nil }

  /// Returns once the fake holds, however many turns that takes: a release sent before it would
  /// release nothing and leave the hold that follows standing for good.
  func untilHeld() async {
    guard held == nil else { return }
    await withCheckedContinuation { holdWaiters.append($0) }
  }

  /// Ends the download in flight as cancelled, a hold included.
  func cancelDownload() {
    cancelled = true
    if downloads > 0 { cancelledDownloads.insert(downloads - 1) }
    release()
  }

  func setForeground(_ foreground: Bool) {
    foregrounds.append(foreground)
  }

  func linkReturned() {
    returns += 1
  }

  /// A download that lists first: the identity, the listing, the dives, the end, with no
  /// progress from the backend.
  static func script(
    _ identity: DiveComputerIdentity, listing: DiveComputerListing, _ dives: [DownloadedDive],
    end: DiveComputerDownloadEnd = .init(.complete)
  ) -> [DiveComputerDownloadEvent] {
    [.identified(identity), .listing(listing)] + dives.map { .dive($0) } + [.finished(end)]
  }

  /// A whole download: the identity, the dives, the end.
  static func script(
    _ identity: DiveComputerIdentity, _ dives: [DownloadedDive],
    end: DiveComputerDownloadEnd = .init(.complete), zone: TimeZone? = nil
  ) -> [DiveComputerDownloadEvent] {
    [.identified(identity)] + (zone.map { [.watchZone($0)] } ?? [])
      + [.progress(current: 10, maximum: 40)] + dives.map { .dive($0) } + [.finished(end)]
  }
}
