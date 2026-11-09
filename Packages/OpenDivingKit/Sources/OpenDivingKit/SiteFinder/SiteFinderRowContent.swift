import Foundation

/// One row of the site finder's list as it is drawn: a site, with its distance from the camera,
/// its mark, and its credit where it is a Commons record; or a place, with how many sites are near.
public struct SiteFinderRowContent: Hashable, Sendable, Identifiable {
  public let id: String
  public let title: String
  /// A site's locality, or a place's full name where it is more than its own.
  public let subtitle: String?
  /// `4.2 km` from the camera; nil without one, and for a site with no pin.
  public let distance: String?
  public let isPlace: Bool
  /// A site's mark; nil on a place.
  public let mark: DiveSiteMark?
  /// A site's credit, owed beside it; a place's goes once under the list.
  public let credit: String?
  /// A place's count of sites near it.
  public let nearby: String?

  public init(_ row: DiveSiteSearchRow, units: UnitSystem) {
    id = row.id
    distance = row.distanceM.map { GeoDistance.format($0, units) }
    switch row {
    case .site(let item):
      title = item.name
      subtitle = item.location?.name
      isPlace = false
      mark = item.mark
      credit = item.attribution
      nearby = nil
    case .place(let item):
      let name = item.place.name?.trimmedOfWhitespace ?? ""
      title = name.isEmpty ? item.place.location : name
      subtitle = name.isEmpty || item.place.location == name ? nil : item.place.location
      isPlace = true
      mark = nil
      credit = nil
      nearby = Self.nearby(item.sitesNearby)
    }
  }

  /// `No sites nearby`, `1 site nearby`, `15 sites nearby`.
  static func nearby(_ count: Int) -> String {
    switch count {
    case ..<1: "No sites nearby"
    case 1: "1 site nearby"
    default: "\(count) sites nearby"
    }
  }

  /// The credits the list's places owe, each once, in the order the rows give them.
  public static func placeCredits(_ rows: [DiveSiteSearchRow]) -> [String] {
    var seen: Set<String> = []
    return rows.compactMap { row in
      guard case .place(let item) = row, seen.insert(item.place.attribution).inserted else {
        return nil
      }
      return item.place.attribution
    }
  }
}
