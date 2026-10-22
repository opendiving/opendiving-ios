/// A named place on a map.
public struct MapPoint: Hashable, Sendable {
  public var name: String
  public var latitude: Double
  public var longitude: Double

  public init(name: String, latitude: Double, longitude: Double) {
    self.name = name
    self.latitude = latitude
    self.longitude = longitude
  }
}
