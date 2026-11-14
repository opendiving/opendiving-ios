import Foundation
import OpenDivingKit

/// A watcher that records what it is asked, and delivers the events a test sends as the central
/// would.
@MainActor
final class FakeDiveComputerWatcher: DiveComputerWatcher {
  enum Call: Hashable {
    case start
    case arm(UUID, after: Int)
    case disarm(UUID)
    case observe(Bool)
  }

  private(set) var calls: [Call] = []
  /// Fails every request in the turn it is made, as iOS fails one it refuses.
  var failsRequests = false
  private var handler: (@MainActor (DiveComputerWatchEvent) -> Void)?

  func start(_ handler: @escaping @MainActor (DiveComputerWatchEvent) -> Void) {
    calls.append(.start)
    self.handler = handler
  }

  func arm(_ peripheral: UUID, after seconds: Int) {
    calls.append(.arm(peripheral, after: seconds))
    if failsRequests {
      handler?(.failedToConnect(peripheral, reason: "One or more parameters were invalid."))
    }
  }

  func disarm(_ peripheral: UUID) {
    calls.append(.disarm(peripheral))
  }

  func observeAdvertisements(_ observing: Bool) {
    calls.append(.observe(observing))
  }

  func send(_ event: DiveComputerWatchEvent) {
    handler?(event)
  }

  /// The calls since the last time this was read.
  func take() -> [Call] {
    defer { calls = [] }
    return calls
  }
}
