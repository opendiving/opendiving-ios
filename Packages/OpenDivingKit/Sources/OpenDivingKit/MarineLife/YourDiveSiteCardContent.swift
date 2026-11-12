import Foundation

/// One card of More's *Your dive sites*, as a trip's card on its list: a map of the site's pin,
/// its name, where it is, in what water, how deep, how high and how divers get in, and what the
/// diver's dives there add up to; then whether a proposal on it waits, and for a Commons record
/// its mark and the credit its source asks for. No distance: the list sends no camera.
public struct YourDiveSiteCardContent: Hashable, Sendable, Identifiable {
  public let id: String
  /// The site the card opens on the map.
  public let siteUUID: UUID?
  /// Its figures empty where the server sends no summary of the diver's dives there.
  public let card: RecordCardContent
  public let isWaitingForReview: Bool
  public let isCommons: Bool
  /// The Commons record's credit, as `[label](href)`.
  public let credit: String?

  /// Nil for a place row, which this list never asks for.
  public init?(_ row: DiveSiteSearchRow, units: UnitSystem) {
    guard case .site(let item) = row else { return nil }
    id = row.id
    siteUUID = item.ref.serverUUID
    card = RecordCardContent(
      title: item.name, facts: Self.facts(item, units: units),
      figures: item.dives.map { Self.figures($0, units: units) } ?? [],
      points: Self.points(item))
    isWaitingForReview = item.isWaitingForReview
    isCommons = item.site.isCommons
    credit = item.site.isCommons ? item.attribution : nil
  }

  /// The site's pin; none for a site with no position, whose card shows the water instead.
  static func points(_ item: DiveSiteSearchItem) -> [MapPoint] {
    guard let latitude = item.latitude, let longitude = item.longitude else { return [] }
    return [MapPoint(name: item.name, latitude: latitude, longitude: longitude)]
  }

  /// The water only where it is not the sea's, and the altitude only where it is not sea
  /// level: both go without saying.
  static func facts(_ item: DiveSiteSearchItem, units: UnitSystem) -> [Fact] {
    var facts: [Fact] = []
    if let location = item.location?.name, !location.isEmpty { facts.append(Fact(text: location)) }
    if let water = item.waterType, !water.isEmpty, water != "salt" {
      facts.append(
        Fact(
          text: VocabularyLabels.waterType(water), icon: .waves, accessibilityLabel: "Water type"))
    }
    if let depth = DiveSiteSummary.depthRange(from: item.depthFrom, to: item.depthTo, units: units)
    {
      facts.append(Fact(text: depth, icon: .arrowDownToLine, accessibilityLabel: "Depth"))
    }
    if let altitude = item.altitude, altitude != 0 {
      facts.append(
        Fact(
          text: UnitFormat.altitude(Double(altitude), units), icon: .mountain,
          accessibilityLabel: "Altitude"))
    }
    if !item.entryTypes.isEmpty {
      facts.append(
        Fact(
          text: item.entryTypes.map(VocabularyLabels.entryType).joined(separator: ", "),
          icon: .wavesArrowDown,
          accessibilityLabel: item.entryTypes.count > 1 ? "Entry types" : "Entry type"))
    }
    return facts
  }

  /// The dives, at one or more; the deepest where there is one, in whole units as a dive card
  /// rounds its depths; the species once there are some.
  static func figures(_ dives: DiveSiteDives, units: UnitSystem) -> [Figure] {
    var figures = [Figure(label: "Dives", value: String(dives.diveCount))]
    if let deepest = dives.maxDiveDepth {
      figures.append(
        Figure(label: "Max depth", value: UnitFormat.depth(deepest, units, decimals: 0)))
    }
    if dives.speciesCount > 0 {
      figures.append(Figure(label: "Species seen", value: String(dives.speciesCount)))
    }
    return figures
  }
}
