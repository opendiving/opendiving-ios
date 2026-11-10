/// What the propose flow's review step shows of a site: what the API would store of it, and the
/// pin on its map.
public struct DiveSiteProposalReview: Hashable, Sendable {
  /// One thing that would be published. Nil where the site records nothing.
  public struct Row: Hashable, Sendable {
    public var label: String
    public var value: String?
  }

  /// A record's pin has six decimals, however many the diver's has.
  static let pinDecimals = 6

  public static let notRecorded = "Not recorded"
  public static let identifierHint = "It stays the same, and it encodes when you created this site."
  public static let licence = "CC0 1.0"
  /// What stays out of the record, and what becomes of what goes in.
  public static let notPublished = [
    "Your notes and your tags stay private, and so do your dives. Who proposed the site is never "
      + "published.",
    "A reviewer reads the above with your name, and may correct it before accepting. An accepted "
      + "record is public and stays, whatever becomes of your account. If it is declined, the "
      + "site stays yours and private, and you are told why.",
  ]

  public var identifier: String
  public var rows: [Row]
  /// The pin as it would be stored, for the map; nil on a site with none.
  public var pin: MapPoint?

  public init(_ site: DiveSiteRead, units: UnitSystem) {
    let latitude = site.latitude.map { NumberText.round($0, decimals: Self.pinDecimals) }
    let longitude = site.longitude.map { NumberText.round($0, decimals: Self.pinDecimals) }
    func text(_ value: String?) -> String? { value?.isEmpty == false ? value : nil }
    let depth = { (meters: Double?) in meters.map { UnitFormat.depth($0, units) } }
    identifier = APIClient.wire(site.uuid)
    rows = [
      Row(label: "Name", value: site.name),
      Row(label: "Other names", value: text(site.otherNames.joined(separator: ", "))),
      Row(
        label: "Pin", value: CoordinateFormat.format(latitude: latitude, longitude: longitude)),
      Row(label: "Location", value: text(site.location?.name)),
      Row(label: "Depth from", value: depth(site.depthFrom)),
      Row(label: "Depth to", value: depth(site.depthTo)),
      Row(label: "Water type", value: site.waterType.map(VocabularyLabels.waterType)),
      Row(label: "Altitude", value: site.altitude.map { UnitFormat.altitude(Double($0), units) }),
      Row(
        label: "Entry types",
        value: text(
          site.entryTypes.map(VocabularyLabels.entryType).joined(separator: ", "))),
      Row(
        label: "Registries",
        value: text(
          DiveSiteSummary.registries(site).map { $0.label + " " + $0.identifier }
            .joined(separator: "\n"))),
    ]
    pin = latitude.flatMap { latitude in
      longitude.map { MapPoint(name: site.name, latitude: latitude, longitude: $0) }
    }
  }
}
