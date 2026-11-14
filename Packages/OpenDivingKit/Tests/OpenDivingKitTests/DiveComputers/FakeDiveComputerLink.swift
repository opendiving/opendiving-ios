import Foundation
import OpenDivingKit

/// A link that replays scripted downloads: the scan finds what the test lists, and each
/// download yields its script's events, calling the lookup as a conformance does once the
/// identity is known and recording what it answered, and keeping each dive before it yields it.
/// Asked for only a paired computer, it ends a script whose identity has no record there,
/// unpaired.
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
  /// The computer each download opened, and whether it asked for a paired one only.
  private(set) var opened: [(computer: FoundComputer, pairedOnly: Bool)] = []
  /// A cancel reached some download.
  private(set) var cancelled = false
  /// The downloads, by index, a cancel reached.
  private var cancelledDownloads: Set<Int> = []
  private var held: CheckedContinuation<Void, Never>?

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
    _ computer: FoundComputer, pairedOnly: Bool,
    lookup: @escaping @Sendable (DiveComputerFamily, String) -> DiveComputerRecord?,
    waiting: @escaping @Sendable (DiveComputerIdentity, Data) -> Bool,
    keep: @escaping @Sendable (DownloadedDive) -> Void
  ) -> AsyncStream<DiveComputerDownloadEvent> {
    let script = scripts.isEmpty ? [] : scripts[min(downloads, scripts.count - 1)]
    let download = downloads
    downloads += 1
    waitingTests.append(waiting)
    opened.append((computer, pairedOnly))
    let (stream, continuation) = AsyncStream.makeStream(of: DiveComputerDownloadEvent.self)
    Task {
      for (index, event) in script.enumerated() {
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
          await withCheckedContinuation { held = $0 }
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

  func release() {
    held?.resume()
    held = nil
  }

  var isHeld: Bool { held != nil }

  /// Ends the download in flight as cancelled, a hold included.
  func cancelDownload() {
    cancelled = true
    if downloads > 0 { cancelledDownloads.insert(downloads - 1) }
    release()
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
