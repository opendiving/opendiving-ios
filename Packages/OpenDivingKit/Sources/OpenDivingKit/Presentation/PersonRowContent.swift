/// One person on a dive, a trip or a course.
public struct PersonRowContent: Hashable, Sendable {
  public var name: String
  /// The linked account's username, without the `@`.
  public var username: String?
  /// The role as the person-role table names it.
  public var role: String?

  public init(name: String, username: String? = nil, role: String? = nil) {
    self.name = name
    self.username = username
    self.role = role
  }
}
