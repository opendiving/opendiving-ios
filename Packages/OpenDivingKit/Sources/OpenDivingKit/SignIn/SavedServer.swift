/// One saved server as the servers screen lists it.
public struct SavedServer: Hashable, Sendable, Identifiable {
  public let origin: ServerOrigin
  /// The server the app is pointed at.
  public let isActive: Bool
  /// *Signed in as diver@example.com*, *Signed in* before the account has loaded, or
  /// *Signed out*.
  public let status: String

  public var id: ServerOrigin { origin }

  /// Every server but the flagship, which stays on the list.
  public var canForget: Bool { !origin.isFlagship }

  public init(origin: ServerOrigin, isActive: Bool, status: String) {
    self.origin = origin
    self.isActive = isActive
    self.status = status
  }
}
