import Foundation

/// `GET /connect-link/{token}`'s answer, to anybody holding the link, signed in or not: whose
/// link it is.
public struct ConnectLinkOwner: Codable, Hashable, Sendable {
  public let name: String
  /// The `v` of `GET /connect-link/{token}/avatar`; null without a picture.
  public let avatarSha256: String?

  public init(name: String, avatarSha256: String? = nil) {
    self.name = name
    self.avatarSha256 = avatarSha256
  }
}
