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
}
