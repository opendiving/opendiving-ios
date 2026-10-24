import Foundation

/// A site a dive visited, with enough of it to place on a map.
public struct DiveSiteInfo: Codable, Hashable, Sendable {
  public var ref: RecordRef
  public var name: String
  /// The locality around the site; its coordinates are the locality's centre, not the pin.
  public var location: LocationRead?
  public var latitude: Double?
  public var longitude: Double?

  enum CodingKeys: String, CodingKey {
    case ref = "uuid"
    case name, location, latitude, longitude
  }

  public init(
    ref: RecordRef, name: String, location: LocationRead? = nil, latitude: Double? = nil,
    longitude: Double? = nil
  ) {
    self.ref = ref
    self.name = name
    self.location = location
    self.latitude = latitude
    self.longitude = longitude
  }
}
