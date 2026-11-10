/// `PATCH /user/checkin-details`'s body. A member left ``Patch/absent`` or nil is not sent and
/// stays as stored; a scalar sent as ``Patch/null`` is cleared; a list sent replaces the stored
/// one whole, `[]` clearing it. The API refuses a list sent as null, and an unknown key.
public struct CheckinDetailsUpdate: Codable, Hashable, Sendable {
  public var email: Patch<String>
  public var phone: Patch<String>
  public var dateOfBirth: Patch<CalendarDate>
  /// At most five, in call order.
  public var emergencyContacts: [EmergencyContactWrite]?
  /// At most five.
  public var insurancePolicies: [InsurancePolicyWrite]?

  public init(
    email: Patch<String> = .absent, phone: Patch<String> = .absent,
    dateOfBirth: Patch<CalendarDate> = .absent, emergencyContacts: [EmergencyContactWrite]? = nil,
    insurancePolicies: [InsurancePolicyWrite]? = nil
  ) {
    self.email = email
    self.phone = phone
    self.dateOfBirth = dateOfBirth
    self.emergencyContacts = emergencyContacts
    self.insurancePolicies = insurancePolicies
  }
}
