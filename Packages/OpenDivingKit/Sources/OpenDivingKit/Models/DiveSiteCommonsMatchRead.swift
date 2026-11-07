import Foundation

/// Why a Commons record may be the same place as a site, as the API spells it, strongest first.
/// Strings rather than an enum, so a later rule reads as sent instead of failing the whole answer.
public enum DiveSiteCommonsMatchRule {
  public static let identity = "identity"
  public static let within20M = "within_20_m"
  public static let similarNameWithin200M = "similar_name_within_200_m"
  public static let sameNameWithin5Km = "same_name_within_5_km"
}

/// A Commons record the diver's own site may be, on `GET /dive-site/{uuid}/commons-matches`.
public struct DiveSiteCommonsMatchRead: Codable, Hashable, Sendable, Identifiable {
  public var id: UUID { uuid }

  public let uuid: UUID
  public let name: String
  public let otherNames: [String]
  public let latitude: Double?
  public let longitude: Double?
  public let locationName: String?
  public let externalIds: [ExternalIdRead]
  /// The credit the record's source asks for, as `[label](href)`.
  public let attribution: String?
  public let rule: String
  /// Between the two pins; nil when the site has none.
  public let distanceMetres: Double?
  /// The names differ only by a word like West or East.
  public let qualifierSiblings: Bool
}
