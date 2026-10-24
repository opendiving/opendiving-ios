/// A contact's postal address.
public struct ContactAddressRead: Codable, Hashable, Sendable {
  public let street: String?
  public let city: String?
  public let postcode: String?
  public let region: String?
  public let country: String

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
