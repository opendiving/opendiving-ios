import Foundation

/// A place row of `GET /dive-sites/search`: the geocoder's answer, how far its centre is from the
/// camera, and how many sites the reader can see near it.
public struct PlaceSearchItem: Codable, Hashable, Sendable {
  public var place: GeocodeResult
  public var distanceM: Double?
  /// Inside the place's box, or within 25 km of its centre where it has none.
  public var sitesNearby: Int

  enum CodingKeys: String, CodingKey {
    case distanceM, sitesNearby
  }

  public init(place: GeocodeResult, distanceM: Double? = nil, sitesNearby: Int) {
    self.place = place
    self.distanceM = distanceM
    self.sitesNearby = sitesNearby
  }

  public init(from decoder: any Decoder) throws {
    place = try GeocodeResult(from: decoder)
    let c = try decoder.container(keyedBy: CodingKeys.self)
    distanceM = try c.decodeIfPresent(Double.self, forKey: .distanceM)
    sitesNearby = try c.decodeIfPresent(Int.self, forKey: .sitesNearby) ?? 0
  }

  public func encode(to encoder: any Encoder) throws {
    try place.encode(to: encoder)
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encodeIfPresent(distanceM, forKey: .distanceM)
    try c.encode(sitesNearby, forKey: .sitesNearby)
  }
}
