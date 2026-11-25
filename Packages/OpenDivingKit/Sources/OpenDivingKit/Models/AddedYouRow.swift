import Foundation

/// One row of `GET /people/added-you`: an account that has the diver in its people and that the
/// diver has not added, by its public id, its current name, username and picture version.
public struct AddedYouRow: Codable, Hashable, Sendable, Identifiable {
  public var id: UUID { uuid }

  public let uuid: UUID
  public let name: String
  public let username: String
  /// The `v` of `GET /people/added-you/{uuid}/avatar`; null without a picture.
  public let avatarSha256: String?

  public init(uuid: UUID, name: String, username: String, avatarSha256: String? = nil) {
    self.uuid = uuid
    self.name = name
    self.username = username
    self.avatarSha256 = avatarSha256
  }
}
