/// A contact's postal address.
public struct ContactAddressRead: Codable, Hashable, Sendable {
  public let street: String?
  public let city: String?
  public let postcode: String?
  public let region: String?
  public let country: String
}
