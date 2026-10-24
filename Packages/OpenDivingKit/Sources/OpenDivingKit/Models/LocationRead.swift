/// A place as a person writes it — the name alone, or extended through its region to its
/// country — with its centre and bounds where they are known.
public struct LocationRead: Codable, Hashable, Sendable {
  public let name: String
  public let latitude: Double?
  public let longitude: Double?
  public let bboxSouth: Double?
  public let bboxNorth: Double?
  public let bboxWest: Double?
  public let bboxEast: Double?

  public init(
    name: String, latitude: Double? = nil, longitude: Double? = nil, bboxSouth: Double? = nil,
    bboxNorth: Double? = nil, bboxWest: Double? = nil, bboxEast: Double? = nil
  ) {
    self.name = name
    self.latitude = latitude
    self.longitude = longitude
    self.bboxSouth = bboxSouth
    self.bboxNorth = bboxNorth
    self.bboxWest = bboxWest
    self.bboxEast = bboxEast
  }
}
