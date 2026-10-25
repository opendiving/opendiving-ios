/// Whether the phone believes it has a route to the network, and the moments worth trying
/// again. The app target conforms over `NWPathMonitor` and the scene phase.
///
/// Every request waits for connectivity, a minute at most, so what the app starts on its own —
/// a queue's flush, files to read — does not start while no route is believed to exist, and
/// a moment is what starts it, and an account load, once one appears. What the diver asks for
/// tries regardless.
public protocol Connectivity: Sendable {
  /// Whether a route is believed to exist now. A belief, not a promise: a request may still
  /// fail with one, and succeed without.
  var isRouteAvailable: Bool { get }

  /// How many routes have appeared since launch, so that work begun with no route can tell
  /// whether one came and went while it waited.
  var routeAppearances: Int { get }

  /// A route appearing and the app returning to the foreground, as one stream. Each call is a
  /// subscription of its own, ending when the task iterating it is cancelled.
  func moments() -> AsyncStream<ConnectivityMoment>
}

/// A moment worth trying again.
public enum ConnectivityMoment: Hashable, Sendable {
  case routeAppeared
  case becameActive
}
