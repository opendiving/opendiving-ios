/// `POST /contact`'s body, `ContactCreate`: a dive centre, a school, a shop, a place to stay.
public struct ContactCreate: Codable, Hashable, Sendable {
  public var name: String
  public var phone: String?
  public var latitude: Double?
  public var longitude: Double?
  public var notes: String
  /// Role keys, `dive_center` or `accommodation`, in any order.
  public var roles: [String]
  public var email: String?
  /// An absolute `http` or `https` URL.
  public var website: String?
  public var address: ContactAddressWrite?

  public init(
    name: String, phone: String? = nil, latitude: Double? = nil, longitude: Double? = nil,
    notes: String = "", roles: [String] = [], email: String? = nil, website: String? = nil,
    address: ContactAddressWrite? = nil
  ) {
    self.name = name
    self.phone = phone
    self.latitude = latitude
    self.longitude = longitude
    self.notes = notes
    self.roles = roles
    self.email = email
    self.website = website
    self.address = address
  }
}

/// A contact's postal address being written, `ContactAddressInput`; the country is required.
public struct ContactAddressWrite: Codable, Hashable, Sendable {
  public var street: String?
  public var city: String?
  public var postcode: String?
  public var region: String?
  public var country: String

  public init(
    street: String? = nil, city: String? = nil, postcode: String? = nil, region: String? = nil,
    country: String
  ) {
    self.street = street
    self.city = city
    self.postcode = postcode
    self.region = region
    self.country = country
  }
}

extension ContactCreate: RewritesLocalRefs {
  /// A contact names no other record.
  public mutating func rewriteRefs(_ rewrite: (RecordRef) -> RecordRef?) {}
}
