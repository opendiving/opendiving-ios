import Foundation

/// One of the account's API keys, as `GET /user/api-keys` lists it: never its secret.
public struct APIKeyRead: Codable, Hashable, Sendable, Identifiable {
  public let uuid: UUID
  /// The label typed when it was made; not unique.
  public let name: String
  /// The secret's first characters, kept so a row can name a key nobody holds any longer.
  public let prefix: String
  public let scope: APIKeyScope
  public let createdAt: DiveTimestamp
  public let lastUsedAt: DiveTimestamp?
  /// Nil for a key that never expires. An expired key is listed until it is revoked.
  public let expiresAt: DiveTimestamp?

  public var id: UUID { uuid }

  public init(
    uuid: UUID, name: String, prefix: String, scope: APIKeyScope, createdAt: DiveTimestamp,
    lastUsedAt: DiveTimestamp?, expiresAt: DiveTimestamp?
  ) {
    self.uuid = uuid
    self.name = name
    self.prefix = prefix
    self.scope = scope
    self.createdAt = createdAt
    self.lastUsedAt = lastUsedAt
    self.expiresAt = expiresAt
  }

  /// Whether the key had lapsed at `now`.
  public func isExpired(at now: Date) -> Bool {
    guard let expires = expiresAt?.instant else { return false }
    return expires <= now
  }
}
