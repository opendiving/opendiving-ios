import Foundation

/// A contact — on this phone's screens, the dive centre on a dive or a card.
public struct ContactRead: Codable, Hashable, Sendable, Identifiable {
  public var id: UUID { uuid }

  public let uuid: UUID
  public let name: String
  public let phone: String?
  public let notes: String
  /// Role keys, as the API sent them.
  public let roles: [String]
  public let email: String?
  /// In the diver's order.
  public let links: [WebLink]
  public let address: ContactAddressRead?
  /// A whole pair or neither.
  public let latitude: Double?
  public let longitude: Double?
  public let userUuid: UUID
  public let createdAt: DiveTimestamp

  public init(from decoder: any Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    uuid = try c.decode(UUID.self, forKey: .uuid)
    name = try c.decode(String.self, forKey: .name)
    phone = try c.decodeIfPresent(String.self, forKey: .phone)
    notes = try c.decode(String.self, forKey: .notes)
    roles = try c.decode([String].self, forKey: .roles)
    email = try c.decodeIfPresent(String.self, forKey: .email)
    links = try c.decodeLinks(forKey: .links)
    address = try c.decodeIfPresent(ContactAddressRead.self, forKey: .address)
    latitude = try c.decodeIfPresent(Double.self, forKey: .latitude)
    longitude = try c.decodeIfPresent(Double.self, forKey: .longitude)
    userUuid = try c.decode(UUID.self, forKey: .userUuid)
    createdAt = try c.decode(DiveTimestamp.self, forKey: .createdAt)
  }
}
