import Foundation

/// One site the finder's map draws, with the mark its pin takes.
public struct SiteFinderMapMark: Hashable, Sendable {
  public let uuid: UUID
  public let latitude: Double
  public let longitude: Double
  public let mark: DiveSiteMark

  public init(uuid: UUID, latitude: Double, longitude: Double, mark: DiveSiteMark) {
    self.uuid = uuid
    self.latitude = latitude
    self.longitude = longitude
    self.mark = mark
  }

  /// Every site in one list, so the diver's and the Commons' are grouped together rather than in
  /// two sets of groups over each other: the diver's own and saved sites, then each Commons record
  /// not among them. Nil `commons` leaves the Commons records out.
  public static func marks(commons: CommonsDiveSitePoints?, yours: [DiveSitePoint])
    -> [SiteFinderMapMark]
  {
    var seen = Set<UUID>()
    var marks: [SiteFinderMapMark] = []
    for point in yours where seen.insert(point.uuid).inserted {
      marks.append(
        SiteFinderMapMark(
          uuid: point.uuid, latitude: point.latitude, longitude: point.longitude, mark: point.mark))
    }
    for point in commons?.points ?? [] where seen.insert(point.uuid).inserted {
      marks.append(
        SiteFinderMapMark(
          uuid: point.uuid, latitude: point.latitude, longitude: point.longitude, mark: .commons))
    }
    return marks
  }

  /// The mark `uuid` is drawn with, as ``marks(commons:yours:)`` draws it: the diver's copy
  /// before the Commons'. Nil for a site the map has no point for.
  public static func mark(of uuid: UUID, commons: CommonsDiveSitePoints?, yours: [DiveSitePoint])
    -> SiteFinderMapMark?
  {
    if let point = yours.first(where: { $0.uuid == uuid }) {
      return SiteFinderMapMark(
        uuid: point.uuid, latitude: point.latitude, longitude: point.longitude, mark: point.mark)
    }
    guard let point = commons?.points.first(where: { $0.uuid == uuid }) else { return nil }
    return SiteFinderMapMark(
      uuid: point.uuid, latitude: point.latitude, longitude: point.longitude, mark: .commons)
  }
}
