/// A server and a session on it, which a developer's script hands a simulator's launch so that
/// the app starts signed in (``ServerStateStore/start(_:)``). A device build reads none.
public struct LaunchSignIn: Hashable, Sendable {
  public let origin: ServerOrigin
  public let refreshToken: String

  public init(origin: ServerOrigin, refreshToken: String) {
    self.origin = origin
    self.refreshToken = refreshToken
  }
}
