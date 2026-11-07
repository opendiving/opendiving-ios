import Foundation

/// What one match in the propose flow's first step prints.
public enum DiveSiteCommonsMatchSummary {
  public struct Row: Hashable, Sendable, Identifiable {
    public var id: UUID { target.uuid }

    /// The record a *Replace with Commons site* names.
    public var target: DiveSiteCommonsMatch
    public var locality: String?
    /// Why it may be the same place, and how far away it is.
    public var reason: String
    public var credit: String?
    /// Says the two are probably not one place, where the names suggest it.
    public var siblings: String?
  }

  public static let none = "No Commons site looks like this one."
  public static let needsPin = "A site needs a pin to be proposed. Edit this site to add one."
  public static let isACopy =
    "This site shares a registry entry with a Commons site, so it is already in the Commons: "
    + "replace it, or propose a change to that one."

  public static func row(_ match: DiveSiteCommonsMatchRead, units: UnitSystem) -> Row {
    var reason = ruleLabel(match.rule)
    if let distance = match.distanceMetres {
      reason += " · " + GeoDistance.format(distance, units) + " away"
    }
    return Row(
      target: DiveSiteCommonsMatch(uuid: match.uuid, name: match.name),
      locality: match.locationName?.isEmpty == false ? match.locationName : nil, reason: reason,
      credit: match.attribution,
      siblings: match.qualifierSiblings
        ? "The names differ only by a word like West or East, which usually means two sites."
        : nil)
  }

  /// Why a Commons record may be the same place as a site.
  public static func ruleLabel(_ rule: String) -> String {
    switch rule {
    case DiveSiteCommonsMatchRule.identity: "Shares a registry entry"
    case DiveSiteCommonsMatchRule.within20M: "Within 20 m, whatever the name"
    case DiveSiteCommonsMatchRule.similarNameWithin200M: "A similar name within 200 m"
    case DiveSiteCommonsMatchRule.sameNameWithin5Km: "The same name within 5 km"
    default: rule
    }
  }
}
