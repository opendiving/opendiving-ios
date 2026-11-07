/// An import's log as its screen draws it: every dive, the ones without a card among them, then
/// what is about no one dive.
public struct ImportLogContent: Hashable, Sendable {
  public let dives: [ImportDiveRow]
  public let notes: [ImportNoteRow]
  /// The sentence that says the note list is not all of them.
  public let notesTruncated: String?

  /// `written` is whether the import has been applied.
  public init(_ log: LogbookImportNotes, written: Bool) {
    dives = ImportDiveRow.rows(log.dives, written: written)
    notes = log.notes.map {
      ImportNoteRow(
        badge: ImportText.noteKind($0.kind), tone: ImportText.noteTone($0.kind),
        text: ImportText.noteText(collection: $0.collection, message: $0.message),
        places: ImportText.notePlaces($0))
    }
    notesTruncated = ImportText.truncatedNotes(log.notesTruncated)
  }
}
