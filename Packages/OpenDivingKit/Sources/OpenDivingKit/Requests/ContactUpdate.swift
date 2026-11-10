/// `PATCH /contact/{uuid}`'s body, `ContactUpdateRequest`: only what is set is sent. The name,
/// the roles and the notes cannot be cleared. `latitude` and `longitude` are one value to the
/// API, so a body names both or neither, and `address` replaces the stored one whole.
public struct ContactUpdate: Codable, Hashable, Sendable {
  public var name: String?
  /// Role keys; replaces the contact's roles.
  public var roles: [String]?
  public var phone: Patch<String>
  public var email: Patch<String>
  public var website: Patch<String>
  public var notes: String?
  public var latitude: Patch<Double>
  public var longitude: Patch<Double>
  public var address: Patch<ContactAddressWrite>

  /// An update that changes nothing; set what changed.
  public init() {
    phone = .absent
    email = .absent
    website = .absent
    latitude = .absent
    longitude = .absent
    address = .absent
  }

  /// Whether sending it would change nothing.
  public var isEmpty: Bool { self == ContactUpdate() }
}

extension ContactUpdate: RewritesLocalRefs {
  /// A contact names no other record.
  public mutating func rewriteRefs(_ rewrite: (RecordRef) -> RecordRef?) {}
}
