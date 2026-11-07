/// `DiveSiteMembersChange`, the `members` of a proposed change to a Commons record: only what the
/// diver wants different is set, and the locality is its name alone. Not ``DiveSiteUpdate``, which
/// carries notes and tags, nests the place, and is refused here.
///
/// The members the API refuses a null for are optionals; every other scalar is a ``Patch``.
/// `latitude` and `longitude` are one value to the API, so a body names both or neither.
public struct DiveSiteMembersChange: Codable, Hashable, Sendable {
  public var name: String?
  public var otherNames: [String]?
  public var externalIds: [ExternalIdWrite]?
  public var entryTypes: [String]?
  public var latitude: Patch<Double>
  public var longitude: Patch<Double>
  /// Metres.
  public var depthFrom: Patch<Double>
  public var depthTo: Patch<Double>
  public var waterType: Patch<String>
  /// Whole metres above sea level.
  public var altitude: Patch<Int>
  public var locationName: Patch<String>

  /// A change that changes nothing; set what differs.
  public init() {
    latitude = .absent
    longitude = .absent
    depthFrom = .absent
    depthTo = .absent
    waterType = .absent
    altitude = .absent
    locationName = .absent
  }

  /// Whether sending it would ask for nothing.
  public var isEmpty: Bool { self == DiveSiteMembersChange() }
}
