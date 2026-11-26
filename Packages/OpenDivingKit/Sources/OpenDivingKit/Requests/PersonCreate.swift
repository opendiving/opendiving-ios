import Foundation

/// `POST /person`'s body, `PersonCreate`. `connectAccount` connects the new person to an account
/// that has a person connected to the diver, as *Added you* lists it, and `connectLink` to a
/// connect link's owner, by the link's token; at most one of them.
public struct PersonCreate: Codable, Hashable, Sendable {
  public var name: String
  public var email: String?
  public var phone: String?
  /// In the diver's order; nil sends none, so a create queued before records carried links
  /// encodes as it was queued.
  public var links: [WebLink]?
  public var notes: String
  public var connectAccount: UUID?
  public var connectLink: String?

  public init(
    name: String, email: String? = nil, phone: String? = nil, links: [WebLink]? = nil,
    notes: String = "", connectAccount: UUID? = nil, connectLink: String? = nil
  ) {
    self.name = name
    self.email = email
    self.phone = phone
    self.links = links
    self.notes = notes
    self.connectAccount = connectAccount
    self.connectLink = connectLink
  }
}

extension PersonCreate {
  private enum CodingKeys: String, CodingKey {
    case name, email, phone, links, notes, connectAccount, connectLink
  }

  public init(from decoder: any Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    name = try c.decode(String.self, forKey: .name)
    email = try c.decodeIfPresent(String.self, forKey: .email)
    phone = try c.decodeIfPresent(String.self, forKey: .phone)
    links = try c.decodeIfPresent([WebLink].self, forKey: .links)
    notes = try c.decode(String.self, forKey: .notes)
    connectAccount = try c.decodeIfPresent(UUID.self, forKey: .connectAccount)
    connectLink = try c.decodeIfPresent(String.self, forKey: .connectLink)
  }

  public func encode(to encoder: any Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(name, forKey: .name)
    try c.encodeIfPresent(email, forKey: .email)
    try c.encodeIfPresent(phone, forKey: .phone)
    try c.encodeIfPresent(links, forKey: .links)
    try c.encode(notes, forKey: .notes)
    try c.encodeWire(connectAccount, forKey: .connectAccount)
    try c.encodeIfPresent(connectLink, forKey: .connectLink)
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
