/// What the phone leaves iOS when an upload cannot reach the server: one background request to
/// the server, naming no account and carrying no dive, whose completion — whenever iOS chooses,
/// once there is a route — wakes or relaunches the app to upload. A protocol because the Kit
/// cannot make a background session: the app conforms it, and the Kit's tests over a fake.
@MainActor
public protocol ServerWake: AnyObject {
  /// Leaves the request, unless one is already left.
  func leave(for origin: ServerOrigin)
}
