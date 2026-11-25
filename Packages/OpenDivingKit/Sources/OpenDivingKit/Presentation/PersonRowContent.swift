import Foundation

/// One person on a dive, a trip or a course.
public struct PersonRowContent: Hashable, Sendable {
  /// The person's page; nil for one the server does not have yet.
  public var uuid: UUID?
  public var name: String
  /// The connected account's username, without the `@`.
  public var username: String?
  /// The connected account's picture, where it has one.
  public var picture: ConnectedPicture?
  /// The role as the person-role table names it.
  public var role: String?

  public init(
    uuid: UUID? = nil, name: String, username: String? = nil, picture: ConnectedPicture? = nil,
    role: String? = nil
  ) {
    self.uuid = uuid
    self.name = name
    self.username = username
    self.picture = picture
    self.role = role
  }
}
