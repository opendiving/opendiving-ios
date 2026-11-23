import Foundation

/// `POST /person`'s body, `PersonCreate`. `connectAccount` connects the new person to an account
/// that has a person connected to the diver, as *Added you* lists it.
public struct PersonCreate: Codable, Hashable, Sendable {
  public var name: String
  public var email: String?
  public var phone: String?
  public var notes: String
  public var connectAccount: UUID?

  public init(
    name: String, email: String? = nil, phone: String? = nil, notes: String = "",
    connectAccount: UUID? = nil
  ) {
    self.name = name
    self.email = email
    self.phone = phone
    self.notes = notes
    self.connectAccount = connectAccount
  }
}

extension PersonCreate {
  private enum CodingKeys: String, CodingKey {
    case name, email, phone, notes, connectAccount
  }

  public init(from decoder: any Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    name = try c.decode(String.self, forKey: .name)
    email = try c.decodeIfPresent(String.self, forKey: .email)
    phone = try c.decodeIfPresent(String.self, forKey: .phone)
    notes = try c.decode(String.self, forKey: .notes)
    connectAccount = try c.decodeIfPresent(UUID.self, forKey: .connectAccount)
  }

  public func encode(to encoder: any Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(name, forKey: .name)
    try c.encodeIfPresent(email, forKey: .email)
    try c.encodeIfPresent(phone, forKey: .phone)
    try c.encode(notes, forKey: .notes)
    try c.encodeWire(connectAccount, forKey: .connectAccount)
  }
}

extension KeyedEncodingContainer {
  /// `uuid` as the API spells one, in lowercase; nothing for nil.
  mutating func encodeWire(_ uuid: UUID?, forKey key: Key) throws {
    try encodeIfPresent(uuid.map(APIClient.wire), forKey: key)
  }
}

extension PersonCreate: RewritesLocalRefs {
  /// A person names no other record.
  public mutating func rewriteRefs(_ rewrite: (RecordRef) -> RecordRef?) {}
}
