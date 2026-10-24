/// A place as a site, a trip part or a contact is given it, `LocationInput`: a name, and its
/// centre and bounds where the place search found them. Latitude and longitude go together,
/// and the four bounds go together and need the centre.
public struct LocationWrite: Codable, Hashable, Sendable {
  public var name: String
  public var latitude: Double?
  public var longitude: Double?
  public var bboxSouth: Double?
  public var bboxNorth: Double?
  public var bboxWest: Double?
  public var bboxEast: Double?

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
