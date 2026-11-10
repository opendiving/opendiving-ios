import Foundation

/// One device signed in to the account, as `GET /user/sessions` lists it.
public struct UserSessionRead: Codable, Hashable, Sendable, Identifiable {
  public let uuid: UUID
  public let createdAt: DiveTimestamp
  public let lastUsedAt: DiveTimestamp
  public let ip: String
  /// The raw header the server saw at sign-in, empty where none was sent; ``DeviceName``
  /// turns it into a label.
  public let userAgent: String
  public let idleTimeout: IdleTimeout
  /// The session the request asking was made on: on the phone, this phone's.
  public let current: Bool

  public var id: UUID { uuid }

  public init(
    uuid: UUID, createdAt: DiveTimestamp, lastUsedAt: DiveTimestamp, ip: String,
    userAgent: String, idleTimeout: IdleTimeout, current: Bool
  ) {
    self.uuid = uuid
    self.createdAt = createdAt
    self.lastUsedAt = lastUsedAt
    self.ip = ip
    self.userAgent = userAgent
    self.idleTimeout = idleTimeout
    self.current = current
  }
}
