/// A ``Connectivity`` that always has a route and never reports a moment: the session's default,
/// for tests and previews and for anything built without the device.
public struct AlwaysReachable: Connectivity {
  public init() {}

  public var isRouteAvailable: Bool { true }

  public var routeAppearances: Int { 0 }

  /// A stream that never yields and stays open until its task is cancelled.
  public func moments() -> AsyncStream<ConnectivityMoment> {
    AsyncStream<ConnectivityMoment>.makeStream().stream
  }
}
