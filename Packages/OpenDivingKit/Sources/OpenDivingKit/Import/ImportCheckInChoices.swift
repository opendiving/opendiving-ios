import Foundation

/// The diver's answers to the check-in details and the portrait a preview offers: each
/// detail the import's unless kept, the portrait the import's unless kept. A kept detail is
/// left out of the apply, which leaves the account's alone.
public struct ImportCheckInChoices: Hashable, Sendable {
  /// The details kept, by ``ImportCheckInDetail/key``.
  public var kept: Set<String>
  public var portraitKept: Bool

  public init(kept: Set<String> = [], portraitKept: Bool = false) {
    self.kept = kept
    self.portraitKept = portraitKept
  }

  /// The apply's `check_in_details`: every detail not kept, as proposed; nil when that is
  /// none.
  public func submission(for details: [ImportCheckInDetail]) -> ImportCheckInSubmission? {
    var submission = ImportCheckInSubmission()
    var any = false
    for detail in details where !kept.contains(detail.key) {
      switch detail {
      case .email(_, let proposed): submission.email = .value(proposed)
      case .phone(_, let proposed): submission.phone = .value(proposed)
      case .dateOfBirth(_, let proposed): submission.dateOfBirth = .value(proposed)
      case .emergencyContacts(_, let proposed):
        submission.emergencyContacts = proposed.map {
          EmergencyContactWrite(name: $0.name, phone: $0.phone, relationship: $0.relationship)
        }
      case .insurancePolicies(_, let proposed):
        submission.insurancePolicies = proposed.map {
          InsurancePolicyWrite(provider: $0.provider, number: $0.number, expiresOn: $0.expiresOn)
        }
      case .other: continue
      }
      any = true
    }
    return any ? submission : nil
  }

  /// The apply's `portrait`, sent whichever way it went once one was offered.
  public func portrait(for offer: ImportPortraitOffer?) -> ImportPortraitChoice? {
    offer.map { ImportPortraitChoice(take: !portraitKept, accountSha256: $0.accountSha256) }
  }
}

extension ImportCheckInDetail {
  /// The detail's wire name, `date_of_birth`.
  public var key: String {
    switch self {
    case .email: "email"
    case .phone: "phone"
    case .dateOfBirth: "date_of_birth"
    case .emergencyContacts: "emergency_contacts"
    case .insurancePolicies: "insurance_policies"
    case .other(let name): name
    }
  }
}
