import Foundation

/// `PATCH /person/{uuid}`'s body, `PersonUpdateRequest`: only what is set is sent. The name and
/// the notes cannot be cleared. `connectAccount` connects a person who is not connected yet to an
/// account that has a person connected to the diver.
public struct PersonUpdate: Hashable, Sendable {
  public var name: String?
  public var email: Patch<String>
  public var phone: Patch<String>
  public var notes: String?
  public var connectAccount: UUID?
  /// Read from a body queued with `username` sent as null, which detached the person: the outbox
  /// sends that as the person's disconnect (``OutboxStore/items()``). Never written.
  var queuedDisconnect = false

  public init(
    name: String? = nil, email: Patch<String> = .absent, phone: Patch<String> = .absent,
    notes: String? = nil, connectAccount: UUID? = nil
  ) {
    self.name = name
    self.email = email
    self.phone = phone
    self.notes = notes
    self.connectAccount = connectAccount
  }

  /// Whether sending it would change nothing.
  public var isEmpty: Bool { self == PersonUpdate() }
}

extension PersonUpdate: Codable {
  private enum CodingKeys: String, CodingKey {
    case name, email, phone, notes, connectAccount, username
  }

  public init(from decoder: any Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    name = try c.decodeIfPresent(String.self, forKey: .name)
    email = try c.decode(Patch<String>.self, forKey: .email)
    phone = try c.decode(Patch<String>.self, forKey: .phone)
    notes = try c.decodeIfPresent(String.self, forKey: .notes)
    connectAccount = try c.decodeIfPresent(UUID.self, forKey: .connectAccount)
    // Any other `username` would have connected by it, which the API no longer does: dropped.
    queuedDisconnect = try c.contains(.username) && c.decodeNil(forKey: .username)
  }

  public func encode(to encoder: any Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encodeIfPresent(name, forKey: .name)
    try c.encode(email, forKey: .email)
    try c.encode(phone, forKey: .phone)
    try c.encodeIfPresent(notes, forKey: .notes)
    try c.encodeWire(connectAccount, forKey: .connectAccount)
  }
}

extension PersonUpdate: RewritesLocalRefs {
  /// A person names no other record.
  public mutating func rewriteRefs(_ rewrite: (RecordRef) -> RecordRef?) {}
}
