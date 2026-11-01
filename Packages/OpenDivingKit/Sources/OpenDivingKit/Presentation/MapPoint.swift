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
}
