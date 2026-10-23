/// One emergency contact on the check-in sheet, in call order.
public struct EmergencyContact: Codable, Hashable, Sendable {
  public let name: String
  public let phone: String?
  /// Free text, not a vocabulary.
  public let relationship: String?
}
