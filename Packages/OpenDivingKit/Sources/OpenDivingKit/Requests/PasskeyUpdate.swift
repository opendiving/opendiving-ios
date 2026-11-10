/// `PATCH /user/passkey/{uuid}`'s body: a rename, the one thing about a passkey a diver owns.
public struct PasskeyUpdate: Codable, Hashable, Sendable {
  public var name: String

  public init(name: String) {
    self.name = name
  }
}
