/// What a dive site's panel and its information card print, from the site as the API reads it.
public enum DiveSiteSummary {
  /// The site's information card, every field the site records but its name, its location and
  /// its tags, which the panel's head carries, and its notes, in the site form's order: each
  /// member only where the site records it.
  public struct Info: Hashable, Sendable {
    /// The other names, `Bells, The Bells`.
    public var alsoKnownAs: String?
    public var coordinates: String?
    /// `5 m – 30 m`, or the one end the site records.
    public var depth: String?
    public var waterType: String?
    public var altitude: String?
    public var entryTypes: String?
    public var registries: [Registry]

    /// One of the card's rows: its label and the value across from it.
    public struct Row: Hashable, Sendable {
      public var label: String
      public var value: String
      /// The value is one to paste elsewhere, as coordinates are, and a tap copies it.
      public var copiesOnTap = false
    }

    /// Each member the site records as a row, in the card's order; its registries, which link
    /// out, follow them.
    public var rows: [Row] {
      let members: [(String, String?, Bool)] = [
        ("Also known as", alsoKnownAs, false), ("Coordinates", coordinates, true),
        ("Depth", depth, false), ("Water type", waterType, false), ("Altitude", altitude, false),
        ("Entry types", entryTypes, false),
      ]
      return members.compactMap { label, value, copies in
        value.map { Row(label: label, value: $0, copiesOnTap: copies) }
      }
    }

    /// A site recording none of them draws no card.
    public var isEmpty: Bool {
      [alsoKnownAs, coordinates, depth, waterType, altitude, entryTypes]
        .allSatisfy { $0 == nil } && registries.isEmpty
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

  /// A tab's name with how many it holds, `My dives (3)`; the name alone for none.
  public static func counted(_ title: String, _ count: Int) -> String {
    count > 0 ? "\(title) (\(count))" : title
  }

  /// The sea's water and sea level too, where the site records them.
  public static func info(_ site: DiveSiteRead, units: UnitSystem) -> Info {
    let text = { (value: String?) in value.flatMap { $0.isEmpty ? nil : $0 } }
    return Info(
      alsoKnownAs: site.otherNames.isEmpty ? nil : site.otherNames.joined(separator: ", "),
      coordinates: CoordinateFormat.format(latitude: site.latitude, longitude: site.longitude),
      depth: depthRange(site, units: units),
      waterType: text(site.waterType).map(VocabularyLabels.waterType),
      altitude: site.altitude.map { UnitFormat.altitude(Double($0), units) },
      entryTypes: site.entryTypes.isEmpty
        ? nil : site.entryTypes.map(VocabularyLabels.entryType).joined(separator: ", "),
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
    add("Location", site.location?.name)
    add("Coordinates", info.coordinates)
    add("Depth", info.depth)
    add("Water type", info.waterType)
    add("Altitude", info.altitude)
    add("Entry types", info.entryTypes)
    for registry in info.registries { add(registry.label, registry.identifier) }
    return members
  }

  /// `5 m – 30 m`, or the one end the site records.
  static func depthRange(_ site: DiveSiteRead, units: UnitSystem) -> String? {
    depthRange(from: site.depthFrom, to: site.depthTo, units: units)
  }

  static func depthRange(from: Double?, to: Double?, units: UnitSystem) -> String? {
    switch (from, to) {
    case (let from?, let to?):
      UnitFormat.depth(from, units) + " – " + UnitFormat.depth(to, units)
    case (let from?, nil): "From " + UnitFormat.depth(from, units)
    case (nil, let to?): "To " + UnitFormat.depth(to, units)
    case (nil, nil): nil
    }
  }
}

extension DiveSiteRead {
  public var mark: DiveSiteMark { DiveSiteMark(owner: owner, proposalStatus: proposal?.status) }
}

extension DiveSiteSearchItem {
  public var name: String { site.name }
  public var location: LocationRead? { site.location }
  public var mark: DiveSiteMark {
    DiveSiteMark(owner: site.owner, proposalStatus: proposal?.status)
  }
}
