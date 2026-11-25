/// Where the phone's credentials are kept: the Keychain on the device, which the app target
/// conforms over because the Kit builds where `Security` does not exist. A server's refresh token
/// is named by the origin, an account's connect-link token by the origin and the account
/// (``ServerStateStore``).
public protocol SecretStore: Sendable {
  func secret(for account: String) throws -> String?
  /// Replaces whatever the account held.
  func setSecret(_ value: String, for account: String) throws
  /// Removing an item that does not exist is not an error.
  func removeSecret(for account: String) throws
}
