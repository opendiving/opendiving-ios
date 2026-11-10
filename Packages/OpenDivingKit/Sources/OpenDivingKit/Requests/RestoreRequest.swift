/// `POST /auth/restore`'s body: the token a deletion-pending sign-in answered, which names the
/// account and is spent by the restore.
public struct RestoreRequest: Codable, Hashable, Sendable {
  public var restoreToken: String

  public init(restoreToken: String) {
    self.restoreToken = restoreToken
  }
}
