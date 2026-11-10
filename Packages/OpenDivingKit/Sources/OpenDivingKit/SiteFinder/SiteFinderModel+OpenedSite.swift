import Foundation

extension SiteFinderModel {
  /// A site the sites map's panel shows: which one, its name, mark and location once anything has
  /// said them, the site itself once its panel has read it, and whether its pin has been put at
  /// the middle of the map.
  public struct OpenedSite: Hashable, Sendable {
    public let uuid: UUID
    public var name: String?
    public var mark: DiveSiteMark?
    /// The place the site is in, `Dahab, Egypt`.
    public var location: String?
    public var site: DiveSiteRead?
    /// The camera has been moved to the site; until then its panel's read of where it is moves
    /// it.
    var isPlaced: Bool

    /// A site the map may have a point for, named and marked as the point is.
    init(_ uuid: UUID, point: SiteFinderPoint?, isPlaced: Bool) {
      self.uuid = uuid
      name = point?.name
      mark = point?.mark
      self.isPlaced = isPlaced
    }

    /// A row of the list, named, marked and placed as the row is.
    init?(_ item: DiveSiteSearchItem) {
      guard let uuid = item.site.ref.serverUUID else { return nil }
      self.uuid = uuid
      name = item.site.name
      mark = item.mark
      location = item.site.location?.name
      isPlaced = item.site.latitude != nil && item.site.longitude != nil
    }
  }
}
