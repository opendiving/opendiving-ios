/// Whether the phone believes it has a route to the network, and the moments worth trying
/// again. The app target conforms over `NWPathMonitor` and the scene phase.
///
/// Nothing decides to send or not to send on it: every request already waits for
/// connectivity. A moment is what starts work that is waiting — a queue's flush, an account
/// load, files to read — so that it runs as soon as it can, never what holds work back.
public protocol Connectivity: Sendable {
  /// Whether a route is believed to exist now. A belief, not a promise: a request may still
  /// fail with one, and succeed without.
  var isRouteAvailable: Bool { get }

  /// A route appearing and the app returning to the foreground, as one stream. Each call is a
  /// subscription of its own, ending when the task iterating it is cancelled.
  func moments() -> AsyncStream<ConnectivityMoment>
}

/// A moment worth trying again.
public enum ConnectivityMoment: Hashable, Sendable {
  case routeAppeared
  case becameActive
}
