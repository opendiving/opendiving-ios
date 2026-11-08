import Foundation

/// `GET /commons/dive-sites/points`: every Commons record with a pin, one document for every
/// account on the instance, with the credit each source asks for.
///
/// Read with a plain decoder, ``decode(_:)``: the keys of `sources` are the source keys the
/// points carry, and the API's snake-case strategy would rewrite them as if they were members.
public struct CommonsDiveSitePoints: Codable, Hashable, Sendable {
  /// Moves whenever a Commons record is added, changed or reviewed.
  public let version: String
  /// The credit each source asks for, as `[label](href)`, by the key a point carries.
  public let sources: [String: String]
  public let points: [CommonsDiveSitePoint]

  public init(version: String, sources: [String: String], points: [CommonsDiveSitePoint]) {
    self.version = version
    self.sources = sources
    self.points = points
  }

  public static func decode(_ data: Data) throws -> CommonsDiveSitePoints {
    try JSONDecoder().decode(CommonsDiveSitePoints.self, from: data)
  }

  /// The credit `point` owes, where its source names one.
  public func credit(_ point: CommonsDiveSitePoint) -> String? {
    sources[point.source]
  }
}

/// One record of ``CommonsDiveSitePoints``, sent as `[longitude, latitude, uuid, name, source]`.
public struct CommonsDiveSitePoint: Codable, Hashable, Sendable {
  public let longitude: Double
  public let latitude: Double
  public let uuid: UUID
  public let name: String
  public let source: String

  public init(longitude: Double, latitude: Double, uuid: UUID, name: String, source: String) {
    self.longitude = longitude
    self.latitude = latitude
    self.uuid = uuid
    self.name = name
    self.source = source
  }

  public init(from decoder: any Decoder) throws {
    var c = try decoder.unkeyedContainer()
    longitude = try c.decode(Double.self)
    latitude = try c.decode(Double.self)
    uuid = try c.decode(UUID.self)
    name = try c.decode(String.self)
    source = try c.decode(String.self)
  }

  public func encode(to encoder: any Encoder) throws {
    var c = encoder.unkeyedContainer()
    try c.encode(longitude)
    try c.encode(latitude)
    try c.encode(uuid)
    try c.encode(name)
    try c.encode(source)
  }
}
