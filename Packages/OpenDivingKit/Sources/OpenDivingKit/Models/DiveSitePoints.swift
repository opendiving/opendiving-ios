import Foundation

/// `GET /dive-sites/points`: every site on the reader's list that has a pin, for a map to draw.
public struct DiveSitePoints: Codable, Hashable, Sendable {
  public let points: [DiveSitePoint]

  public init(points: [DiveSitePoint]) {
    self.points = points
  }
}

/// One site of ``DiveSitePoints``, sent as `[longitude, latitude, uuid, name, owner]`.
public struct DiveSitePoint: Codable, Hashable, Sendable {
  public let longitude: Double
  public let latitude: Double
  public let uuid: UUID
  public let name: String
  /// `account` or `opendivingcommons`, as ``DiveSiteOwner`` spells them.
  public let owner: String

  public init(longitude: Double, latitude: Double, uuid: UUID, name: String, owner: String) {
    self.longitude = longitude
    self.latitude = latitude
    self.uuid = uuid
    self.name = name
    self.owner = owner
  }

  public var isCommons: Bool { owner == DiveSiteOwner.commons }

  public init(from decoder: any Decoder) throws {
    var c = try decoder.unkeyedContainer()
    longitude = try c.decode(Double.self)
    latitude = try c.decode(Double.self)
    uuid = try c.decode(UUID.self)
    name = try c.decode(String.self)
    owner = try c.decode(String.self)
  }

  public func encode(to encoder: any Encoder) throws {
    var c = encoder.unkeyedContainer()
    try c.encode(longitude)
    try c.encode(latitude)
    try c.encode(uuid)
    try c.encode(name)
    try c.encode(owner)
  }
}
