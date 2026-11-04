/// A named place on a map.
public struct MapPoint: Hashable, Sendable {
  public var name: String
  public var latitude: Double
  public var longitude: Double
  /// The place's footprint where a geocoder gave one, which a map fits rather than the point,
  /// so a country does not open at the zoom of its centroid.
  public var bounds: LatLonBounds?

  public init(name: String, latitude: Double, longitude: Double, bounds: LatLonBounds? = nil) {
    self.name = name
    self.latitude = latitude
    self.longitude = longitude
    self.bounds = bounds
  }

  /// From this width a footprint says nothing about longitude: a geocoder sends a place across
  /// the antimeridian as nearly or wholly the world, Fiji as -180 to 180. The web's
  /// `placedLocations` draws the line here too.
  static let worldCirclingSpan = 350.0

  /// What a fit fits: the footprint, or the point where there is none. A footprint that circles
  /// the world keeps its south and north and is as many degrees wide as tall around the place's
  /// own longitude, so a place really that wide shows around its point and not whole.
  var extent: LatLonBounds {
    guard let bounds else {
      return LatLonBounds(south: latitude, north: latitude, west: longitude, east: longitude)
    }
    guard bounds.longitudeSpan >= Self.worldCirclingSpan else { return bounds }
    let halfWidth = abs(bounds.north - bounds.south) / 2
    return LatLonBounds(
      south: bounds.south, north: bounds.north, west: longitude - halfWidth,
      east: longitude + halfWidth)
  }
}
