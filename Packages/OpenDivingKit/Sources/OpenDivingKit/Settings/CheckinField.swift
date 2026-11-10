import Foundation

/// One box of the check-in details, which a refusal is shown under. A row's boxes are named by
/// the row's ``CheckinDetailsDraft/Contact/id`` or ``CheckinDetailsDraft/Policy/id``.
public enum CheckinField: Hashable, Sendable {
  case email
  case phone
  case dateOfBirth
  case contactName(UUID)
  case contactPhone(UUID)
  case contactRelationship(UUID)
  case policyProvider(UUID)
  case policyNumber(UUID)

  /// The group whose save checks it.
  public var group: CheckinGroup {
    switch self {
    case .email, .phone, .dateOfBirth: .about
    case .contactName, .contactPhone, .contactRelationship: .emergency
    case .policyProvider, .policyNumber: .insurance
    }
  }
}
