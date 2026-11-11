import Foundation

extension SiteFinderModel {
  /// A site the sites map's panel shows: which one, its name, mark, location and pin once anything
  /// has said them, the site itself once its panel has read it, and whether its pin has been put at
  /// the middle of the map.
  public struct OpenedSite: Hashable, Sendable {
    public let uuid: UUID
    public var name: String?
    public var mark: DiveSiteMark?
    /// The place the site is in, `Dahab, Egypt`.
    public var location: String?
    /// Where its pin is.
    public var pin: DeviceLocation?
    public var site: DiveSiteRead?
    /// The camera has been moved to the site; until then its panel's read of where it is moves
    /// it.
    var isPlaced: Bool

    /// A site the map may have a point for, named and marked as the point is.
    init(_ uuid: UUID, point: SiteFinderPoint?, isPlaced: Bool) {
      self.uuid = uuid
      name = point?.name
      mark = point?.mark
      pin = point.map { DeviceLocation(latitude: $0.latitude, longitude: $0.longitude) }
      self.isPlaced = isPlaced
    }

    /// A row of the list, named, marked and placed as the row is.
    init?(_ item: DiveSiteSearchItem) {
      guard let uuid = item.site.ref.serverUUID else { return nil }
      self.uuid = uuid
      name = item.site.name
      mark = item.mark
      location = item.site.location?.name
      if let latitude = item.site.latitude, let longitude = item.site.longitude {
        pin = DeviceLocation(latitude: latitude, longitude: longitude)
      }
      isPlaced = pin != nil
    }

    /// What the weather at its pin is titled: the place it is in, the name the site already holds
    /// rather than one asked of a geocoder, else its own name.
    public var weatherTitle: String? {
      [location, name].lazy.compactMap { $0?.trimmedOfWhitespace }.first { !$0.isEmpty }
    }
  }
}
