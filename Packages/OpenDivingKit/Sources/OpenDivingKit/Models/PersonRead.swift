import Foundation

/// A person in the diver's address book, as `GET /people` lists them.
public struct PersonRead: Codable, Hashable, Sendable, Identifiable {
  public var id: UUID { uuid }

  public let uuid: UUID
  public let name: String
  public let email: String?
  public let phone: String?
  public let notes: String
  /// The linked account's current username; null when the person is not linked to one.
  public let username: String?
  public let diveCount: Int
  public let createdAt: DiveTimestamp
  public let updatedAt: DiveTimestamp?
}
