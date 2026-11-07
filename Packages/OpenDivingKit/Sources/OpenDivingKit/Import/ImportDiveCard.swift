import Foundation


/// One dive of a review or a result as a card: a `new` or `modified` row with a dive to draw.
public struct ImportDiveCard: Sendable, Identifiable {
  /// What tapping the card does.
  public enum Tap: Hashable, Sendable {
    /// Opens the sheet: every card of a review, and a modified card once applied, whose before
    /// and after are nowhere else.
    case sheet
    /// Opens the dive a new card became.
    case dive(UUID)
    /// Nothing: an applied row whose dive has no uuid to open.
    case none
  }

  /// The row's position, since two rows can name one uuid.
  public let id: Int
  public let content: DiveCardContent
  /// Says which dive the card opens, one card apart from the next.
  public let accessibilityLabel: String
  public let tap: Tap
  private let row: LogbookImportDive
  private let dive: DiveReadWithMixtures
  private let isApplied: Bool

  /// The cards of `dives`, the rows without one being the log's to name.
  public static func cards(_ dives: [LogbookImportDive], applied: Bool, units: UnitSystem)
    -> [ImportDiveCard]
  {
    dives.enumerated().compactMap { index, row in
      guard let dive = row.dive, let content = DiveCardContent.dive(row, units: units) else {
        return nil
      }
      let name = content.title + ", " + DateText.diveDateTime(dive.startTime)
      let isNew = row.outcome == "new"
      return ImportDiveCard(
        id: index, content: content,
        accessibilityLabel: isNew ? "New dive: " + name : "What changes on " + name,
        tap: !applied || !isNew ? .sheet : row.uuid.map(Tap.dive) ?? .none,
        row: row, dive: dive, isApplied: applied)
    }
  }

  /// Whether any of `dives` has no card, so that only the log names it.
  public static func leavesRowsOut(_ dives: [LogbookImportDive]) -> Bool {
    dives.contains { $0.dive == nil || !["new", "modified"].contains($0.outcome) }
  }

  /// What the card's sheet shows, built on the tap rather than for every card of an import.
  public func sheet(units: UnitSystem) -> ImportDiveSheet {
    guard row.outcome == "modified" else {
      return .info(
        title: content.title, sections: DiveDetailContent.reviewInfo(dive, units: units))
    }
    return .changes(
      title: content.title, rows: row.changes.map { ImportChangeRow.row($0, units: units) },
      opens: isApplied ? row.uuid : nil)
  }
}

/// A card's sheet: a new dive whole, or only what the import changes on a dive the diver has.
public enum ImportDiveSheet: Hashable, Sendable {
  case info(title: String, sections: [RecordInfoSection])
  /// `opens` is the dive a written import changed, where the sheet links it.
  case changes(title: String, rows: [ImportChangeRow], opens: UUID?)
}
