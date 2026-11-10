import Foundation

/// One row of More's *Your dive sites*, as the web's finder draws a site under *Your sites*:
/// its name; where it is, in what water, how deep, how high and how divers get in; what the
/// diver's dives there add up to; whether a proposal on it waits; and for a Commons record its
/// mark and the credit its source asks for. No distance: the list sends no camera.
public struct YourDiveSiteRowContent: Hashable, Sendable, Identifiable {
  public let id: String
  /// The site the row opens on the map.
  public let siteUUID: UUID?
  public let title: String
  public let facts: [Fact]
  /// `12 dives · deepest 31 m · 4 species seen`; nil where the server sends no summary.
  public let figures: String?
  public let isWaitingForReview: Bool
  public let isCommons: Bool
  /// The Commons record's credit, as `[label](href)`.
  public let credit: String?

  /// Nil for a place row, which this list never asks for.
  public init?(_ row: DiveSiteSearchRow, units: UnitSystem) {
    guard case .site(let item) = row else { return nil }
    id = row.id
    siteUUID = item.ref.serverUUID
    title = item.name
    facts = Self.facts(item, units: units)
    figures = item.dives.map { Self.figures($0, units: units) }
    isWaitingForReview = item.isWaitingForReview
    isCommons = item.site.isCommons
    credit = item.site.isCommons ? item.attribution : nil
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

  static func figures(_ dives: DiveSiteDives, units: UnitSystem) -> String {
    var parts = ["\(dives.diveCount) \(dives.diveCount == 1 ? "dive" : "dives")"]
    if let deepest = dives.maxDiveDepth {
      parts.append("deepest " + UnitFormat.depth(deepest, units, decimals: 0))
    }
    if dives.speciesCount > 0 { parts.append("\(dives.speciesCount) species seen") }
    return parts.joined(separator: " · ")
  }
}
