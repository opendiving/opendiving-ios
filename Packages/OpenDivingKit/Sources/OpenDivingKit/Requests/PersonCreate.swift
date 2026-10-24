/// `POST /person`'s body, `PersonCreate`. `username` links the person to an account on this
/// instance, by its exact username.
public struct PersonCreate: Codable, Hashable, Sendable {
  public var name: String
  public var email: String?
  public var phone: String?
  public var notes: String
  public var username: String?

  public init(
    name: String, email: String? = nil, phone: String? = nil, notes: String = "",
    username: String? = nil
  ) {
    self.name = name
    self.email = email
    self.phone = phone
    self.notes = notes
    self.username = username
  }
}

extension PersonCreate: RewritesLocalRefs {
  /// A person names no other record.
  public mutating func rewriteRefs(_ rewrite: (RecordRef) -> RecordRef?) {}
}
