import Foundation

/// A person in the diver's address book, as `GET /people` lists them.
public struct PersonRead: Codable, Hashable, Sendable, Identifiable {
  public var id: UUID { uuid }

  public let uuid: UUID
  public let name: String
  public let email: String?
  public let phone: String?
  /// Addresses to open, in the diver's order; never who the person is.
  public let links: [WebLink]
  public let notes: String
  /// The connected account's current username; null when the person is not connected to one.
  public let username: String?
  /// The connected account's picture version, the `v` of `GET /person/{uuid}/avatar`; null when
  /// the person is not connected, or the account has no picture or has asked to be deleted.
  public let avatarSha256: String?
  public let diveCount: Int
  public let createdAt: DiveTimestamp
  public let updatedAt: DiveTimestamp?

  public init(from decoder: any Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    uuid = try c.decode(UUID.self, forKey: .uuid)
    name = try c.decode(String.self, forKey: .name)
    email = try c.decodeIfPresent(String.self, forKey: .email)
    phone = try c.decodeIfPresent(String.self, forKey: .phone)
    links = try c.decodeLinks(forKey: .links)
    notes = try c.decode(String.self, forKey: .notes)
    username = try c.decodeIfPresent(String.self, forKey: .username)
    avatarSha256 = try c.decodeIfPresent(String.self, forKey: .avatarSha256)
    diveCount = try c.decode(Int.self, forKey: .diveCount)
    createdAt = try c.decode(DiveTimestamp.self, forKey: .createdAt)
    updatedAt = try c.decodeIfPresent(DiveTimestamp.self, forKey: .updatedAt)
  }
}
