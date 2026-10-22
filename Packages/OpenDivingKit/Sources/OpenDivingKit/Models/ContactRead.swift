import Foundation

/// A contact — on this phone's screens, the dive centre on a dive or a card.
public struct ContactRead: Codable, Hashable, Sendable {
  public let uuid: UUID
  public let name: String
  public let phone: String?
  public let notes: String
  /// Role keys, as the API sent them.
  public let roles: [String]
  public let email: String?
  public let website: String?
  public let address: ContactAddressRead?
  /// A whole pair or neither.
  public let latitude: Double?
  public let longitude: Double?
  public let userUuid: UUID
  public let createdAt: DiveTimestamp
}
