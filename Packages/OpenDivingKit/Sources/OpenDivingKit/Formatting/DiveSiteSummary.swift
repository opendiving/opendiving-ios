/// What a dive site's card, its page's hero and its information card print, from the site
/// as the API reads it.
public enum DiveSiteSummary {
  /// The site's *Dive Site Information* card: each member only where the site records it.
  public struct Info: Hashable, Sendable {
    /// The other names, `Bells, The Bells`.
    public var alsoKnownAs: String?
    public var coordinates: String?
    public var tags: [String]
    public var registries: [Registry]

    /// A site recording none of them draws no card.
    public var isEmpty: Bool {
      alsoKnownAs == nil && coordinates == nil && tags.isEmpty && registries.isEmpty
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

  /// The site's card on the sites list: its name, its facts, and its dives, its deepest —
  /// a dash where it has none — and its species once there are some.
  public static func card(_ site: DiveSiteRead, units: UnitSystem) -> RecordCardContent {
    var figures = [
      Figure(label: "Dives", value: String(site.diveCount)),
      Figure(label: "Deepest", value: deepest(site, units: units)),
    ]
    if site.speciesCount > 0 {
      figures.append(Figure(label: "Species seen", value: String(site.speciesCount)))
    }
    return RecordCardContent(title: site.name, facts: facts(site, units: units), figures: figures)
  }

  /// The site's page's head: its card the width of the screen, over a map of its pin when
  /// it has one. Only the figures the site has are shown, and its last dive last, as the
  /// one figure wider than the rest.
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
    // The pin alone: the locality's centre is the town a geocoder resolved, not the site.
    var points: [MapPoint] = []
    if let latitude = site.latitude, let longitude = site.longitude {
      points.append(MapPoint(name: site.name, latitude: latitude, longitude: longitude))
    }
    return HeroContent(
      title: site.name, facts: facts(site, units: units), figures: figures, points: points)
  }

  /// Where the site is, in what water, how deep, how high and how divers get in — each only
  /// where the site records it, the water only where it is not the sea's and the altitude
  /// only where it is not sea level, both of which go without saying.
  public static func facts(_ site: DiveSiteRead, units: UnitSystem) -> [Fact] {
    var facts: [Fact] = []
    if let place = site.location?.name, !place.isEmpty {
      facts.append(Fact(text: place))
    }
    if let waterType = site.waterType, !waterType.isEmpty, waterType != "salt" {
      facts.append(
        Fact(
          text: VocabularyLabels.waterType(waterType), systemImage: "water.waves",
          accessibilityLabel: "Water type"))
    }
    if let depths = depthRange(site, units: units) {
      facts.append(
        Fact(text: depths, systemImage: "arrow.down.to.line", accessibilityLabel: "Depth"))
    }
    if let altitude = site.altitude, altitude != 0 {
      facts.append(
        Fact(
          text: UnitFormat.altitude(Double(altitude), units), systemImage: "mountain.2",
          accessibilityLabel: "Altitude"))
    }
    if !site.entryTypes.isEmpty {
      facts.append(
        Fact(
          text: site.entryTypes.map(VocabularyLabels.entryType).joined(separator: ", "),
          systemImage: "water.waves.and.arrow.down",
          accessibilityLabel: site.entryTypes.count > 1 ? "Entry types" : "Entry type"))
    }
    return facts
  }

  public static func info(_ site: DiveSiteRead) -> Info {
    Info(
      alsoKnownAs: site.otherNames.isEmpty ? nil : site.otherNames.joined(separator: ", "),
      coordinates: CoordinateFormat.format(latitude: site.latitude, longitude: site.longitude),
      tags: site.tags,
      registries: site.externalIds.map { entry in
        Registry(
          label: ExternalIdRegistry.label(entry.registry), identifier: entry.identifier,
          link: ExternalIdRegistry.link(registry: entry.registry, identifier: entry.identifier))
      })
  }

  /// `5 m – 30 m`, or the one end the site records.
  static func depthRange(_ site: DiveSiteRead, units: UnitSystem) -> String? {
    switch (site.depthFrom, site.depthTo) {
    case (let from?, let to?):
      UnitFormat.depth(from, units) + " – " + UnitFormat.depth(to, units)
    case (let from?, nil): "From " + UnitFormat.depth(from, units)
    case (nil, let to?): "To " + UnitFormat.depth(to, units)
    case (nil, nil): nil
    }
  }

  /// The deepest dive there, in whole units as a dive card rounds its depths.
  private static func deepest(_ site: DiveSiteRead, units: UnitSystem) -> String? {
    site.maxDiveDepth.map { UnitFormat.depth($0, units, decimals: 0) }
  }
}
