/// `GET /user/checkin-details`. An account that saved nothing reads as nulls and empty lists.
public struct CheckinDetailsRead: Codable, Hashable, Sendable {
  /// The address the diver gives out, not the sign-in one.
  public let email: String?
  public let phone: String?
  public let dateOfBirth: CalendarDate?
  public let emergencyContacts: [EmergencyContact]
  public let insurancePolicies: [InsurancePolicy]
}
