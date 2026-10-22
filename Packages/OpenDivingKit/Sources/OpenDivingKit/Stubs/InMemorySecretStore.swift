import Synchronization

/// A ``SecretStore`` that forgets everything with the process.
public final class InMemorySecretStore: SecretStore {
  private let secrets: Mutex<[String: String]>

  public init(_ secrets: [String: String] = [:]) {
    self.secrets = Mutex(secrets)
  }

  public func secret(for account: String) throws -> String? {
    secrets.withLock { $0[account] }
  }

  public func setSecret(_ value: String, for account: String) throws {
    secrets.withLock { $0[account] = value }
  }

  public func removeSecret(for account: String) throws {
    _ = secrets.withLock { $0.removeValue(forKey: account) }
  }
}
