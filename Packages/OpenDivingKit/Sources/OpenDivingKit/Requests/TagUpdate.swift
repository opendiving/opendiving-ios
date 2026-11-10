/// `PATCH /tag/{uuid}`'s body: a rename, the one thing a tag has to change.
public struct TagUpdate: Codable, Hashable, Sendable {
  public var name: String

  public init(name: String) {
    self.name = name
  }
}
