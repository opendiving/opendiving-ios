/// What a dive site's card, its panel's head and its information card print, from the site
/// as the API reads it.
public enum DiveSiteSummary {
  /// The site's *Dive Site Information* card, every field the site records but its name and its
  /// notes, in the site form's order: each member only where the site records it.
  public struct Info: Hashable, Sendable {
    /// The other names, `Bells, The Bells`.
    public var alsoKnownAs: String?
    public var location: String?
    public var coordinates: String?
    /// `5 m – 30 m`, or the one end the site records.
    public var depth: String?
    public var waterType: String?
    public var altitude: String?
    public var entryTypes: String?
    public var tags: [String]
    public var registries: [Registry]

    /// A site recording none of them draws no card.
    public var isEmpty: Bool {
      [alsoKnownAs, location, coordinates, depth, waterType, altitude, entryTypes]
        .allSatisfy { $0 == nil } && tags.isEmpty && registries.isEmpty
    }
  }

  /// One entry in another registry: the registry as a reader knows it and the identifier,
  /// opening the registry's own page where the format names the registry.
  public struct Registry: Hashable, Sendable {
    public var label: String
    public var identifier: String
    public var link: String?

    public init(label: String, identifier: String, link: String? = nil) {
      self.label = label
      self.identifier = identifier
      self.link = link
    }
  }

  /// One thing a Commons record says, as its edit form shows it: not the diver's to change.
  public struct SharedMember: Hashable, Sendable {
    public var label: String
    public var value: String
  }

  /// The mark on a Commons site, wherever one is listed or shown.
  public static let commonsLabel = "Commons"

  /// What the head of a Commons site's panel carries.
  public static func chips(_ site: some DiveSiteCardSource) -> [Chip] {
    site.isCommons ? [DiveSiteMark.commons.chip] : []
  }

  /// The site's card on the sites list: its name under its mark, its facts, and its dives, its
  /// deepest —
  /// a dash where it has none — and its species once there are some, over a map of its pin.
  public static func card(_ site: some DiveSiteCardSource, units: UnitSystem)
    -> RecordCardContent
  {
    var figures = [
      Figure(label: "Dives", value: String(site.diveCount)),
      Figure(label: "Deepest", value: deepest(site, units: units)),
    ]
    if site.speciesCount > 0 {
      figures.append(Figure(label: "Species seen", value: String(site.speciesCount)))
    }
    return RecordCardContent(
      title: site.name, chips: [site.mark.chip], facts: facts(site, units: units),
      figures: figures, points: points(site))
  }

  /// The head of the site's panel, whose name and mark stand over it, whose pin is the map's and
  /// whose facts are its information card's: its figures. Only the figures the site has are shown, and its last dive last,
  /// as the one figure wider than the rest.
  public static func hero(_ site: DiveSiteRead, units: UnitSystem) -> HeroContent {
    var figures = [Figure(label: "Dives", value: String(site.diveCount))]
    if let deepest = deepest(site, units: units) {
      figures.append(Figure(label: "Deepest", value: deepest))
    }
    if site.speciesCount > 0 {
      figures.append(Figure(label: "Species seen", value: String(site.speciesCount)))
    }
    if let lastDivedOn = site.lastDivedOn {
      figures.append(Figure(label: "Last dive", value: DateText.date(lastDivedOn)))
    }
    return HeroContent(
      title: site.name, chips: chips(site), facts: facts(site, units: units), figures: figures,
      points: points(site))
  }

  /// The site's pin alone, where it has one: its locality's centre is the town a geocoder
  /// resolved, not the site.
  public static func points(_ site: some DiveSiteCardSource) -> [MapPoint] {
    guard let latitude = site.latitude, let longitude = site.longitude else { return [] }
    return [MapPoint(name: site.name, latitude: latitude, longitude: longitude)]
  }

  /// Where the site is, in what water, how deep, how high and how divers get in — each only
  /// where the site records it, the water only where it is not the sea's and the altitude
  /// only where it is not sea level, both of which go without saying.
  public static func facts(_ site: some DiveSiteCardSource, units: UnitSystem) -> [Fact] {
    var facts: [Fact] = []
    if let place = site.location?.name, !place.isEmpty {
      facts.append(Fact(text: place))
    }
    if let waterType = site.waterType, !waterType.isEmpty, waterType != "salt" {
      facts.append(
        Fact(
          text: VocabularyLabels.waterType(waterType), icon: .waves,
          accessibilityLabel: "Water type"))
    }
    if let depths = depthRange(site, units: units) {
      facts.append(
        Fact(text: depths, icon: .arrowDownToLine, accessibilityLabel: "Depth"))
    }
    if let altitude = site.altitude, altitude != 0 {
      facts.append(
        Fact(
          text: UnitFormat.altitude(Double(altitude), units), icon: .mountain,
          accessibilityLabel: "Altitude"))
    }
    if !site.entryTypes.isEmpty {
      facts.append(
        Fact(
          text: site.entryTypes.map(VocabularyLabels.entryType).joined(separator: ", "),
          icon: .wavesArrowDown,
          accessibilityLabel: site.entryTypes.count > 1 ? "Entry types" : "Entry type"))
    }
    return facts
  }

  /// Unlike the facts line, the sea's water and sea level are shown where the site records them.
  public static func info(_ site: DiveSiteRead, units: UnitSystem) -> Info {
    let text = { (value: String?) in value.flatMap { $0.isEmpty ? nil : $0 } }
    return Info(
      alsoKnownAs: site.otherNames.isEmpty ? nil : site.otherNames.joined(separator: ", "),
      location: text(site.location?.name),
      coordinates: CoordinateFormat.format(latitude: site.latitude, longitude: site.longitude),
      depth: depthRange(site, units: units),
      waterType: text(site.waterType).map(VocabularyLabels.waterType),
      altitude: site.altitude.map { UnitFormat.altitude(Double($0), units) },
      entryTypes: site.entryTypes.isEmpty
        ? nil : site.entryTypes.map(VocabularyLabels.entryType).joined(separator: ", "),
      tags: site.tags,
      registries: registries(site))
  }

  /// The site's entries in other registries, each opening the registry's page where the format
  /// names the registry.
  public static func registries(_ site: DiveSiteRead) -> [Registry] {
    site.externalIds.map { entry in
      Registry(
        label: ExternalIdRegistry.label(entry.registry), identifier: entry.identifier,
        link: ExternalIdRegistry.link(registry: entry.registry, identifier: entry.identifier))
    }
  }

  /// A Commons record's facts, each only where it records it.
  public static func sharedMembers(_ site: DiveSiteRead, units: UnitSystem) -> [SharedMember] {
    let info = info(site, units: units)
    var members = [SharedMember(label: "Name", value: site.name)]
    func add(_ label: String, _ value: String?) {
      if let value, !value.isEmpty { members.append(SharedMember(label: label, value: value)) }
    }
    add("Also known as", info.alsoKnownAs)
    add("Location", info.location)
    add("Coordinates", info.coordinates)
    add("Depth", info.depth)
    add("Water type", info.waterType)
    add("Altitude", info.altitude)
    add("Entry types", info.entryTypes)
    for registry in info.registries { add(registry.label, registry.identifier) }
    return members
  }

  /// `5 m – 30 m`, or the one end the site records.
  static func depthRange(_ site: some DiveSiteCardSource, units: UnitSystem) -> String? {
    switch (site.depthFrom, site.depthTo) {
    case (let from?, let to?):
      UnitFormat.depth(from, units) + " – " + UnitFormat.depth(to, units)
    case (let from?, nil): "From " + UnitFormat.depth(from, units)
    case (nil, let to?): "To " + UnitFormat.depth(to, units)
    case (nil, nil): nil
    }
  }

  /// The deepest dive there, in whole units as a dive card rounds its depths.
  private static func deepest(_ site: some DiveSiteCardSource, units: UnitSystem) -> String? {
    site.maxDiveDepth.map { UnitFormat.depth($0, units, decimals: 0) }
  }
}

/// What a site's card reads: a site as the API reads it, or a row of the site finder's list.
public protocol DiveSiteCardSource {
  var name: String { get }
  var location: LocationRead? { get }
  var latitude: Double? { get }
  var longitude: Double? { get }
  var waterType: String? { get }
  var depthFrom: Double? { get }
  var depthTo: Double? { get }
  var altitude: Int? { get }
  var entryTypes: [String] { get }
  var isCommons: Bool { get }
  var mark: DiveSiteMark { get }
  var diveCount: Int { get }
  var maxDiveDepth: Double? { get }
  var speciesCount: Int { get }
}

extension DiveSiteRead: DiveSiteCardSource {
  public var mark: DiveSiteMark { DiveSiteMark(owner: owner, proposalStatus: proposal?.status) }
}

extension DiveSiteSearchItem: DiveSiteCardSource {
  public var name: String { site.name }
  public var location: LocationRead? { site.location }
  public var latitude: Double? { site.latitude }
  public var longitude: Double? { site.longitude }
  public var waterType: String? { site.waterType }
  public var altitude: Int? { site.altitude }
  public var entryTypes: [String] { site.entryTypes }
  public var isCommons: Bool { site.isCommons }
  public var mark: DiveSiteMark {
    DiveSiteMark(owner: site.owner, proposalStatus: proposal?.status)
  }
  public var diveCount: Int { dives?.diveCount ?? 0 }
  public var maxDiveDepth: Double? { dives?.maxDiveDepth }
  public var speciesCount: Int { dives?.speciesCount ?? 0 }
}
