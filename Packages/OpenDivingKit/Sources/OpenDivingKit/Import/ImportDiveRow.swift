import Foundation

/// One dive of an import's log, as the screen draws it.
public struct ImportDiveRow: Hashable, Sendable, Identifiable {
  /// The row's position, since a skipped dive has no uuid and two rows can name one.
  public let id: Int
  public let start: String
  /// The computer that recorded it, on a row that names one.
  public let recordedBy: String?
  public let outcome: String
  /// Why a skipped dive was skipped.
  public let reason: String?
  /// The dive to open, where the row links one: every dive of a written import the apply did not
  /// skip, whose uuid can name a dive gone since, and in a review only the dives the diver already
  /// has.
  public let opens: UUID?
  public let notes: [ImportNoteRow]
  /// The sentence that says the API cut the row's notes.
  public let notesTruncated: String?

  /// The rows of a log. `written` is whether its import has been applied.
  public static func rows(_ dives: [LogbookImportDiveNotes], written: Bool) -> [ImportDiveRow] {
    dives.enumerated().map { index, row in
      let linkable = row.outcome != "skipped" && (written || row.outcome != "new")
      return ImportDiveRow(
        id: index,
        start: ImportText.start(row.startTime),
        recordedBy: row.device.map {
          RecordingLabels.device(brand: $0.brand, model: $0.model, serial: $0.serial, name: $0.name)
            ?? RecordingLabels.unnamedDevice
        },
        outcome: ImportText.diveOutcome(row.outcome),
        reason: row.reason,
        opens: linkable ? row.uuid : nil,
        notes: row.notes.map {
          ImportNoteRow(
            badge: ImportText.noteKind($0.kind), tone: ImportText.noteTone($0.kind),
            text: ImportText.noteText(
              collection: $0.collection, message: $0.message, implied: "dives"),
            places: nil)
        },
        notesTruncated: ImportText.truncatedDiveNotes(row.notesTruncated))
    }
  }
}

/// One note of an import's log.
public struct ImportNoteRow: Hashable, Sendable {
  public let badge: String?
  public let tone: ImportNoteTone
  public let text: String
  /// How often it came up and where.
  public let places: String?
}
