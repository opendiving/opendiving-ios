import Foundation

/// A site a dive visited, with enough of it to place on a map.
public struct DiveSiteInfo: Codable, Hashable, Sendable {
  public let uuid: UUID
  public let name: String
  /// The locality around the site; its coordinates are the locality's centre, not the pin.
  public let location: LocationRead?
  public let latitude: Double?
  public let longitude: Double?
}
