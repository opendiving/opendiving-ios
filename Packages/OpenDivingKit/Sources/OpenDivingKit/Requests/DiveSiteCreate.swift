/// `POST /dive-site`'s body, `DiveSiteCreate`. The pin is `latitude` and `longitude`, both or
/// neither; `location` is the locality around it.
public struct DiveSiteCreate: Codable, Hashable, Sendable {
  public var name: String
  public var latitude: Double?
  public var longitude: Double?
  public var notes: String
  public var otherNames: [String]
  public var externalIds: [ExternalIdWrite]
  /// Metres.
  public var depthFrom: Double?
  public var depthTo: Double?
  public var waterType: String?
  /// Whole metres above sea level, −450 to 6500.
  public var altitude: Int?
  public var entryTypes: [String]
  public var location: LocationWrite?
  public var tags: [String]

  public init(
    name: String, latitude: Double? = nil, longitude: Double? = nil, notes: String = "",
    otherNames: [String] = [], externalIds: [ExternalIdWrite] = [], depthFrom: Double? = nil,
    depthTo: Double? = nil, waterType: String? = nil, altitude: Int? = nil,
    entryTypes: [String] = [], location: LocationWrite? = nil, tags: [String] = []
  ) {
    self.name = name
    self.latitude = latitude
    self.longitude = longitude
    self.notes = notes
    self.otherNames = otherNames
    self.externalIds = externalIds
    self.depthFrom = depthFrom
    self.depthTo = depthTo
    self.waterType = waterType
    self.altitude = altitude
    self.entryTypes = entryTypes
    self.location = location
    self.tags = tags
  }
}

extension DiveSiteCreate: RewritesLocalRefs {
  /// A site names no other record.
  public mutating func rewriteRefs(_ rewrite: (RecordRef) -> RecordRef?) {}
}
