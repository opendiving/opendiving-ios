import Foundation

/// `GET /connect-link/{token}/owner`'s answer to a signed-in diver: whose link it is, and where
/// the diver already stands with them.
public struct ConnectLinkOwnerForYou: Codable, Hashable, Sendable {
  public let name: String
  public let username: String
  /// The `v` of `GET /connect-link/{token}/avatar`; null without a picture.
  public let avatarSha256: String?
  /// Whether the link is the diver's own.
  public let isYours: Bool
  /// The diver's person connected to the owner, if there is one.
  public let personUuid: UUID?

  public init(
    name: String, username: String, avatarSha256: String? = nil, isYours: Bool = false,
    personUuid: UUID? = nil
  ) {
    self.name = name
    self.username = username
    self.avatarSha256 = avatarSha256
    self.isYours = isYours
    self.personUuid = personUuid
  }
}
