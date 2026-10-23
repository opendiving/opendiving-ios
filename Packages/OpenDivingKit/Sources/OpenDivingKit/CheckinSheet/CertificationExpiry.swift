/// Whether a card's expiry is worth flagging. Most cards never expire and are flagged
/// nothing, so there is no "valid" case to bury the two that matter.
public enum CertificationExpiry: Hashable, Sendable {
  case expiringSoon
  case expired

  /// How far ahead a card counts as expiring soon: the notice a renewal course needs. The
  /// web's `CERTIFICATION_EXPIRING_SOON_DAYS`.
  public static let expiringSoonDays = 90

  /// Nil for a card with no expiry, or one that expires more than ``expiringSoonDays`` after
  /// `today`.
  public init?(expiresOn: CalendarDate?, today: CalendarDate) {
    guard let expiresOn else { return nil }
    let daysLeft = expiresOn.daysSinceEpoch - today.daysSinceEpoch
    if daysLeft < 0 {
      self = .expired
    } else if daysLeft <= Self.expiringSoonDays {
      self = .expiringSoon
    } else {
      return nil
    }
  }

  public var label: String {
    switch self {
    case .expiringSoon: "Expiring soon"
    case .expired: "Expired"
    }
  }
}
