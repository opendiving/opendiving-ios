import Foundation

/// One dive row of an import's review or result, as the screen draws it.
public struct ImportDiveRow: Hashable, Sendable, Identifiable {
  public struct Note: Hashable, Sendable {
    public let badge: String?
    public let tone: ImportNoteTone
    public let text: String
  }

  /// The row's position, since a skipped dive has no uuid and two rows can name one.
  public let id: Int
  public let start: String
  public let diveTime: String
  public let depth: String
  public let recordedBy: String
  public let files: [String]
  public let outcome: String
  /// The dive to open, where the row links one: every written dive in a result, and in a
  /// review only the dives the diver already has.
  public let opens: UUID?
  public let notes: [Note]
  public let truncatedNotes: String?

  /// The rows of `dives`, whose `members` index into `members`. `written` is whether they
  /// are a result's.
  public static func rows(
    _ dives: [ImportDiveReport], members: [ImportMemberReport], units: UnitSystem, written: Bool
  ) -> [ImportDiveRow] {
    dives.enumerated().map { index, dive in
      let linkable = written || dive.outcome == "linked" || dive.outcome == "updated"
      return ImportDiveRow(
        id: index,
        start: ImportText.start(dive.startTime),
        diveTime: dive.submergedTime.map(ImportText.diveTime) ?? "—",
        depth: dive.maxDepth.map { UnitFormat.depth($0, units, decimals: 1) } ?? "—",
        recordedBy: dive.device.map {
          RecordingLabels.device(brand: $0.brand, model: $0.model, serial: $0.serial, name: $0.name)
            ?? RecordingLabels.unnamedDevice
        } ?? "—",
        files: dive.members.compactMap { members.indices.contains($0) ? members[$0].name : nil },
        outcome: ImportText.diveOutcome(dive),
        opens: linkable ? dive.uuid : nil,
        notes: dive.notes.map {
          Note(
            badge: ImportText.noteKind($0.kind), tone: ImportText.noteTone($0.kind),
            text: ImportText.noteText(collection: $0.collection, message: $0.message, implied: "dives"))
        },
        truncatedNotes: ImportText.truncatedDiveNotes(dive.notesTruncated))
    }
  }
}
