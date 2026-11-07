import Foundation

/// One dive row of an import's review or result, as the screen draws it.
public struct ImportDiveRow: Hashable, Sendable, Identifiable {
  /// The row's position, since a skipped dive has no uuid and two rows can name one.
  public let id: Int
  public let start: String
  public let diveTime: String
  public let depth: String
  public let recordedBy: String
  public let files: [String]
  public let outcome: String
  /// Why a skipped dive was skipped.
  public let reason: String?
  /// The dive to open, where the row links one: every dive of a result the apply did not skip,
  /// whose uuid can name a dive gone since, and in a review only the dives the diver already has.
  public let opens: UUID?

  /// The rows of `dives`, whose `members` index into `members`. `written` is whether they
  /// are a result's.
  public static func rows(
    _ dives: [LogbookImportDive], members: [ImportMemberReport], units: UnitSystem, written: Bool
  ) -> [ImportDiveRow] {
    dives.enumerated().map { index, row in
      let linkable = row.outcome != "skipped" && (written || row.outcome != "new")
      return ImportDiveRow(
        id: index,
        start: ImportText.start(row.startTime),
        diveTime: row.dive.map { ImportText.diveTime($0.dive.submergedTime) } ?? "—",
        depth: row.dive?.dive.maxDepth.map { UnitFormat.depth($0, units, decimals: 1) } ?? "—",
        recordedBy: row.device.map {
          RecordingLabels.device(brand: $0.brand, model: $0.model, serial: $0.serial, name: $0.name)
            ?? RecordingLabels.unnamedDevice
        } ?? "—",
        files: row.members.compactMap { members.indices.contains($0) ? members[$0].name : nil },
        outcome: ImportText.diveOutcome(row),
        reason: row.reason,
        opens: linkable ? row.uuid : nil)
    }
  }
}
