import Foundation
import OpenDivingKit
import Testing

/// The log's rows and notes from `GET /import/{uuid}/notes`.
struct ImportLogContentTests {
  private func log(written: Bool = true) throws -> ImportLogContent {
    ImportLogContent(
      try KitFixture.decode(LogbookImportNotes.self, "import-notes"), written: written)
  }

  @Test func eachDiveSaysItsOutcomeAndItsNotes() throws {
    let content = try log()
    let modified = content.dives[0]
    #expect(modified.outcome == "Modified")
    #expect(modified.start == "Sep 8, 2026, 15:17 +03:00")
    #expect(modified.recordedBy == "Suunto Ocean · D0000000 (Ocean)")
    #expect(modified.reason == nil)
    #expect(modified.notes.first?.text.hasPrefix("A recording of this dive") == true)
    #expect(modified.notes.first?.places == nil)
  }

  @Test func aSkippedRowSaysWhyAndOpensNothing() throws {
    let skipped = try log().dives[1]
    #expect(skipped.outcome == "Skipped")
    #expect(skipped.opens == nil)
    #expect(skipped.recordedBy == nil)
    #expect(
      skipped.reason
        == "This dive's file could no longer be read when the import was applied, so nothing "
        + "was written for it.")
  }

  @Test func theGroupsFollowWithTheirTruncation() throws {
    let content = try log()
    #expect(
      content.notes.map(\.text) == ["1 tag is new to your logbook: drift."].map { "Dives: " + $0 })
    #expect(content.notesTruncated == "1 further note is not shown.")
  }

  private func notes(_ outcome: String, uuid: UUID?, truncated: Int = 0) throws
    -> LogbookImportDiveNotes
  {
    let json: [String: Any] = [
      "uuid": uuid?.uuidString.lowercased() ?? NSNull(), "start_time": NSNull(),
      "device": NSNull(), "outcome": outcome, "reason": NSNull(), "notes": [[String: Any]](),
      "notes_truncated": truncated,
    ]
    return try APICoding.decoder().decode(
      LogbookImportDiveNotes.self, from: JSONSerialization.data(withJSONObject: json))
  }

  @Test func aRowOpensADiveThatExists() throws {
    let uuid = UUID()
    let opens = { (outcome: String, written: Bool) in
      ImportDiveRow.rows([try self.notes(outcome, uuid: uuid)], written: written)[0].opens
    }
    #expect(try opens("new", false) == nil)
    #expect(try opens("modified", false) == uuid)
    #expect(try opens("unchanged", false) == uuid)
    #expect(try opens("skipped", false) == nil)
    #expect(try opens("new", true) == uuid)
    // A row the apply skipped keeps the uuid the review gave it, of a dive gone since.
    #expect(try opens("skipped", true) == nil)
    let unshown = try notes("new", uuid: nil)
    #expect(ImportDiveRow.rows([unshown], written: true)[0].opens == nil)
  }

  @Test func aCutRowSaysSo() throws {
    let row = ImportDiveRow.rows([try notes("new", uuid: nil, truncated: 2)], written: true)[0]
    #expect(
      row.notesTruncated
        == "2 further notes about this dive are listed with the import's notes below.")
  }
}
