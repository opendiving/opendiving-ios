/// A place `GET /geocode/search` or `GET /geocode/reverse` found: its centre, the name a pick
/// saves as the location, and its bounds where the provider has them.
public struct GeocodeResult: Codable, Hashable, Sendable {
  public let latitude: Double
  public let longitude: Double
  /// `Dahab, South Sinai, Egypt`: the place, its region and its country.
  public let location: String
  /// The feature's own name, where it has one.
  public let name: String?
  /// What the provider's licence asks to be shown with the result.
  public let attribution: String
  public let country: String?
  public let region: String?
  public let source: String?
  public let sourceId: String?
  public let bboxSouth: Double?
  public let bboxNorth: Double?
  public let bboxWest: Double?
  public let bboxEast: Double?
}

/// What `GET /geocode/reverse` learned about a position.
public enum ReverseGeocode: Hashable, Sendable {
  case named(GeocodeResult)
  /// The position was looked up and has no name: a location typed for it may be cleared.
  case nameless
  /// The instance could not ask — geocoding off, over its cap, the provider unreachable —
  /// so nothing was learned, and nothing typed should be cleared.
  case unknown
}
