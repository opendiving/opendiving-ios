/// `PATCH /dive-site/{uuid}`'s body, `DiveSiteUpdateRequest`: only what is set is sent.
///
/// The members the API refuses a null for are optionals, so a null cannot be written for them;
/// every other scalar is a ``Patch``, where ``Patch/null`` clears it. A list replaces the site's
/// whole list and `location` the whole place. `latitude` and `longitude` are one value to the
/// API, so a body names both or neither.
public struct DiveSiteUpdate: Codable, Hashable, Sendable {
  public var name: String?
  public var notes: String?
  public var otherNames: [String]?
  public var externalIds: [ExternalIdWrite]?
  public var entryTypes: [String]?
  public var tags: [String]?
  public var latitude: Patch<Double>
  public var longitude: Patch<Double>
  /// Metres.
  public var depthFrom: Patch<Double>
  public var depthTo: Patch<Double>
  public var waterType: Patch<String>
  /// Whole metres above sea level.
  public var altitude: Patch<Int>
  public var location: Patch<LocationWrite>

  /// An update that changes nothing; set what changed.
  public init() {
    latitude = .absent
    longitude = .absent
    depthFrom = .absent
    depthTo = .absent
    waterType = .absent
    altitude = .absent
    location = .absent
  }

  /// Whether sending it would change nothing.
  public var isEmpty: Bool { self == DiveSiteUpdate() }
}

extension DiveSiteUpdate: RewritesLocalRefs {
  /// A site names no other record.
  public mutating func rewriteRefs(_ rewrite: (RecordRef) -> RecordRef?) {}
}
