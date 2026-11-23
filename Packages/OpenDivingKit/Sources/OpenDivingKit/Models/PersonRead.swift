import Foundation

/// A person in the diver's address book, as `GET /people` lists them.
public struct PersonRead: Codable, Hashable, Sendable, Identifiable {
  public var id: UUID { uuid }

  public let uuid: UUID
  public let name: String
  public let email: String?
  public let phone: String?
  public let notes: String
  /// The connected account's current username; null when the person is not connected to one.
  public let username: String?
  /// The connected account's picture version, the `v` of `GET /person/{uuid}/avatar`; null when
  /// the person is not connected, or the account has no picture or has asked to be deleted.
  public let avatarSha256: String?
  public let diveCount: Int
  public let createdAt: DiveTimestamp
  public let updatedAt: DiveTimestamp?
}
