/// `PATCH /person/{uuid}`'s body, `PersonUpdateRequest`: only what is set is sent. The name and
/// the notes cannot be cleared; a null `username` detaches the person from the account it
/// names.
public struct PersonUpdate: Codable, Hashable, Sendable {
  public var name: String?
  public var email: Patch<String>
  public var phone: Patch<String>
  public var notes: String?
  public var username: Patch<String>

  public init(
    name: String? = nil, email: Patch<String> = .absent, phone: Patch<String> = .absent,
    notes: String? = nil, username: Patch<String> = .absent
  ) {
    self.name = name
    self.email = email
    self.phone = phone
    self.notes = notes
    self.username = username
  }

  /// Whether sending it would change nothing.
  public var isEmpty: Bool { self == PersonUpdate() }
}

extension PersonUpdate: RewritesLocalRefs {
  /// A person names no other record.
  public mutating func rewriteRefs(_ rewrite: (RecordRef) -> RecordRef?) {}
}
