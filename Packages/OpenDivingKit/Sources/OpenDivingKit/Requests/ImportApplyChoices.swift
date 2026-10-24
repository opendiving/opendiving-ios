import Foundation

/// The check-in details the diver kept or edited in an import's preview, sent back with the
/// apply as `check_in_details`. A member left ``Patch/absent`` or nil is not written; a scalar
/// sent as ``Patch/null`` is cleared; a list sent replaces the account's whole list.
public struct ImportCheckInSubmission: Codable, Hashable, Sendable {
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

/// One emergency contact being written; the name is required.
public struct EmergencyContactWrite: Codable, Hashable, Sendable {
  public var name: String
  public var phone: String?
  public var relationship: String?

  public init(name: String, phone: String? = nil, relationship: String? = nil) {
    self.name = name
    self.phone = phone
    self.relationship = relationship
  }
}

/// One insurance policy being written; the provider is required.
public struct InsurancePolicyWrite: Codable, Hashable, Sendable {
  public var provider: String
  public var number: String?
  public var expiresOn: CalendarDate?

  public init(provider: String, number: String? = nil, expiresOn: CalendarDate? = nil) {
    self.provider = provider
    self.number = number
    self.expiresOn = expiresOn
  }
}

/// Whether the archive's portrait replaces the account's, sent with the apply as `portrait`.
/// `accountSha256` is the preview's ``ImportPortraitOffer/accountSha256``, written as null when
/// the account had none, so a portrait changed since the preview is kept.
public struct ImportPortraitChoice: Hashable, Sendable {
  public var take: Bool
  public var accountSha256: String?

  public init(take: Bool, accountSha256: String?) {
    self.take = take
    self.accountSha256 = accountSha256
  }
}

extension ImportPortraitChoice: Codable {
  enum CodingKeys: String, CodingKey { case choice, accountSha256 }

  public init(from decoder: any Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    take = try c.decode(String.self, forKey: .choice) == "take"
    accountSha256 = try c.decodeIfPresent(String.self, forKey: .accountSha256)
  }

  public func encode(to encoder: any Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(take ? "take" : "keep", forKey: .choice)
    try c.encode(accountSha256, forKey: .accountSha256)
  }
}
