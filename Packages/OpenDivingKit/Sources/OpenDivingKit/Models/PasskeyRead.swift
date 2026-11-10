import Foundation

/// One passkey on the account, as `GET /user/passkeys` lists it: what tells one from another,
/// never the credential itself.
public struct PasskeyRead: Codable, Hashable, Sendable, Identifiable {
  public let uuid: UUID
  public let name: String
  /// The authenticator's backup flag: a synced passkey survives a lost device, and one without
  /// it does not.
  public let backedUp: Bool
  public let createdAt: DiveTimestamp
  /// Nil for a passkey that has never signed in.
  public let lastUsedAt: DiveTimestamp?

  public var id: UUID { uuid }

  public init(
    uuid: UUID, name: String, backedUp: Bool, createdAt: DiveTimestamp, lastUsedAt: DiveTimestamp?
  ) {
    self.uuid = uuid
    self.name = name
    self.backedUp = backedUp
    self.createdAt = createdAt
    self.lastUsedAt = lastUsedAt
  }

  /// This passkey under another name.
  public func renamed(_ name: String) -> PasskeyRead {
    PasskeyRead(
      uuid: uuid, name: name, backedUp: backedUp, createdAt: createdAt, lastUsedAt: lastUsedAt)
  }
}
