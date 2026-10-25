import Network
import OpenDivingKit
import Synchronization
import UIKit

/// The Kit's ``Connectivity`` over `NWPathMonitor` and the app becoming active: whether the app's
/// own sends and reads start, and when work that is waiting is worth trying again.
nonisolated final class PathMonitorConnectivity: Connectivity {
  /// What a path update says that matters here.
  struct Path: Equatable, Sendable {
    var satisfied: Bool
    /// The interface kinds the path runs over, so a move from Wi-Fi to cellular is a change.
    var interfaces: Set<String>
  }

  private struct State {
    var path: Path?
    var appearances = 0
    var subscribers: [UUID: AsyncStream<ConnectivityMoment>.Continuation] = [:]
  }

  private let state = Mutex(State())
  private let monitor: NWPathMonitor?
  /// Written once in `init` and read in `deinit`, never concurrently.
  nonisolated(unsafe) private var observer: (any NSObjectProtocol)?

  /// The device's: a monitor on its own queue, and the app's activation notification.
  convenience init() {
    self.init(monitor: NWPathMonitor())
  }

  /// `monitor` nil leaves the path to ``receive(_:)``, for a test.
  init(monitor: NWPathMonitor?) {
    self.monitor = monitor
    monitor?.pathUpdateHandler = { [weak self] path in
      self?.receive(
        Path(
          satisfied: path.status == .satisfied,
          interfaces: Set(path.availableInterfaces.map { "\($0.type)" })))
    }
    monitor?.start(queue: DispatchQueue(label: "app.opendiving.path-monitor"))
    guard monitor != nil else { return }
    observer = NotificationCenter.default.addObserver(
      forName: UIApplication.didBecomeActiveNotification, object: nil, queue: nil
    ) { [weak self] _ in
      self?.becameActive()
    }
  }

  deinit {
    monitor?.cancel()
    if let observer { NotificationCenter.default.removeObserver(observer) }
  }

  /// Before the monitor's first update the route is assumed, so a launch holds nothing back.
  var isRouteAvailable: Bool {
    state.withLock { $0.path?.satisfied ?? true }
  }

  var routeAppearances: Int {
    state.withLock { $0.appearances }
  }

  func moments() -> AsyncStream<ConnectivityMoment> {
    let (stream, continuation) = AsyncStream<ConnectivityMoment>.makeStream()
    let id = UUID()
    state.withLock { $0.subscribers[id] = continuation }
    continuation.onTermination = { [weak self] _ in
      _ = self?.state.withLock { $0.subscribers.removeValue(forKey: id) }
    }
    return stream
  }

  /// A path update: a satisfied path that differs from the last one is a route appearing.
  func receive(_ path: Path) {
    let subscribers = state.withLock { state -> [AsyncStream<ConnectivityMoment>.Continuation] in
      let previous = state.path
      state.path = path
      guard path.satisfied, path != previous else { return [] }
      state.appearances += 1
      return Array(state.subscribers.values)
    }
    for subscriber in subscribers { subscriber.yield(.routeAppeared) }
  }

  func becameActive() {
    for subscriber in state.withLock({ Array($0.subscribers.values) }) {
      subscriber.yield(.becameActive)
    }
  }
}
