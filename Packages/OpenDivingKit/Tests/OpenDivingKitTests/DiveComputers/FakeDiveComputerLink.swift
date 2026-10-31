import Foundation
import OpenDivingKit

/// A link that replays scripted downloads: the scan finds what the test lists, and each
/// download yields its script's events, calling the lookup as a conformance does once the
/// identity is known and recording what it answered.
@MainActor
final class FakeDiveComputerLink: DiveComputerLink {
  var state = DiveComputerAvailability.on
  var found: [FoundComputer] = []
  /// One script per download, in order; the last repeats.
  var scripts: [[DiveComputerDownloadEvent]] = []
  /// Held before the script's last event until ``release()``.
  var holdBeforeEnd = false
  private(set) var downloads = 0
  private(set) var fingerprintsSet: [Data?] = []
  private(set) var cancelled = false
  private var held: CheckedContinuation<Void, Never>?

  func availability() -> AsyncStream<DiveComputerAvailability> {
    AsyncStream {
      $0.yield(state)
      $0.finish()
    }
  }

  func scan() -> AsyncStream<FoundComputer> {
    let found = found
    return AsyncStream { continuation in
      for computer in found { continuation.yield(computer) }
      continuation.finish()
    }
  }

  func download(
    _ computer: FoundComputer,
    lookup: @escaping @Sendable (DiveComputerFamily, String) -> DiveComputerRecord?
  ) -> AsyncStream<DiveComputerDownloadEvent> {
    let script = scripts.isEmpty ? [] : scripts[min(downloads, scripts.count - 1)]
    downloads += 1
    let (stream, continuation) = AsyncStream.makeStream(of: DiveComputerDownloadEvent.self)
    Task {
      for (index, event) in script.enumerated() {
        if case .identified(let identity) = event {
          fingerprintsSet.append(lookup(identity.family, identity.serial.lowercased())?.fingerprint)
        }
        if index == script.count - 1, holdBeforeEnd {
          await withCheckedContinuation { held = $0 }
        }
        if case .finished = event, cancelled {
          continuation.yield(.finished(.init(.cancelled)))
        } else {
          continuation.yield(event)
        }
        await Task.yield()
      }
      continuation.finish()
    }
    return stream
  }

  func release() {
    held?.resume()
    held = nil
  }

  var isHeld: Bool { held != nil }

  func cancelDownload() { cancelled = true }

  /// A whole download: the identity, the dives, the end.
  static func script(
    _ identity: DiveComputerIdentity, _ dives: [DownloadedDive],
    end: DiveComputerDownloadEnd = .init(.complete), zone: TimeZone? = nil
  ) -> [DiveComputerDownloadEvent] {
    [.identified(identity)] + (zone.map { [.watchZone($0)] } ?? [])
      + [.progress(current: 10, maximum: 40)] + dives.map { .dive($0) } + [.finished(end)]
  }
}
