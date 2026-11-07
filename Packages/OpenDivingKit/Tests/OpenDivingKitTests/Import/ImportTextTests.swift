import Foundation
import OpenDivingKit
import Testing

/// The import screen's bounds and sentences, against the web's Import page.
struct ImportTextTests {
  private let mb = 1024 * 1024

  @Test func theFourBoundsAreTheWebs() {
    #expect(ImportBounds.fileRefusal(filename: "season.ZIP", byteSize: 500 * mb) == nil)
    #expect(
      ImportBounds.fileRefusal(filename: "season.zip", byteSize: 500 * mb + 1)
        == "A zip may be up to 500 MB.")
    #expect(ImportBounds.fileRefusal(filename: "dive.fit", byteSize: 100 * mb) == nil)
    #expect(
      ImportBounds.fileRefusal(filename: "dive.fit", byteSize: 100 * mb + 1)
        == "A file that is not a zip may be up to 100 MB. Import the full-export archive if you "
        + "are restoring a whole account with its files.")
    #expect(ImportBounds.selectionRefusal(byteSizes: Array(repeating: 1, count: 1000)) == nil)
    #expect(
      ImportBounds.selectionRefusal(byteSizes: Array(repeating: 1, count: 1001))
        == "One import may carry up to 1000 files. Zip them and import the zip instead.")
    #expect(
      ImportBounds.selectionRefusal(byteSizes: [300 * mb, 200 * mb + 1])
        == "One import may carry up to 500 MB. Import these files in parts.")
  }

  private func row(_ outcome: String, uuid: UUID? = UUID(), reason: String? = nil) throws
    -> LogbookImportDive
  {
    let json: [String: Any] = [
      "uuid": uuid?.uuidString.lowercased() ?? NSNull(), "outcome": outcome, "dive": NSNull(),
      "changes": [], "start_time": NSNull(), "device": NSNull(), "members": [Int](),
      "reason": reason ?? NSNull(),
    ]
    return try APICoding.decoder().decode(
      LogbookImportDive.self, from: JSONSerialization.data(withJSONObject: json))
  }

  @Test func theRowsReadAsTheWebsDo() throws {
    let pending = try KitFixture.decode(LogbookImportRead.self, "import-pending")
    let rows = ImportDiveRow.rows(
      pending.dives, members: pending.members, units: .metric, written: false)
    let first = try #require(rows.first)
    #expect(first.start == "Sep 8, 2026, 15:17 +03:00")
    #expect(first.diveTime == "51:03")
    #expect(first.depth == "19.0 m")
    #expect(first.recordedBy == "Suunto Ocean")
    #expect(first.outcome == "New")
    #expect(first.files == ["dive-0214.fit"])
    #expect(first.opens == nil)
    #expect(ImportText.memberStatus(pending.members[0]) == ("FIT · kept on its dive", false))
    #expect(
      ImportText.memberStatus(pending.members[1])
        == ("Refused: This file is not one OpenDiving reads.", true))
  }

  @Test func theOutcomesReadInTheDiversTerms() throws {
    #expect(ImportText.diveOutcome(try row("new")) == "New")
    #expect(ImportText.diveOutcome(try row("modified")) == "Modified")
    #expect(ImportText.diveOutcome(try row("unchanged")) == "Already in your logbook")
    #expect(ImportText.diveOutcome(try row("skipped")) == "Skipped")
    #expect(ImportText.diveOutcome(try row("something_new")) == "something_new")
  }

  @Test func aRowOpensADiveThatExists() throws {
    let uuid = UUID()
    let opens = { (outcome: String, written: Bool) in
      ImportDiveRow.rows(
        [try self.row(outcome, uuid: uuid)], members: [], units: .metric, written: written)[0].opens
    }
    #expect(try opens("new", false) == nil)
    #expect(try opens("modified", false) == uuid)
    #expect(try opens("unchanged", false) == uuid)
    #expect(try opens("skipped", false) == nil)
    #expect(try opens("new", true) == uuid)
    // A row the apply skipped keeps the uuid the review gave it, of a dive gone since.
    #expect(try opens("skipped", true) == nil)
  }

  @Test func aSkippedRowSaysWhyOnceBeneathItsOutcome() throws {
    let dive = try row(
      "skipped", uuid: nil, reason: "A dive needs a start time, and this one has none.")
    let first = try #require(
      ImportDiveRow.rows([dive], members: [], units: .metric, written: false).first)
    #expect(first.outcome == "Skipped")
    #expect(first.reason == "A dive needs a start time, and this one has none.")
  }

  @Test func theButtonCountsWhatIsWrittenAndNeverClaimsTheNegative() throws {
    #expect(ImportText.buttonLabel([try row("new")]) == "Import 1 dive")
    #expect(
      ImportText.buttonLabel([try row("new"), try row("modified"), try row("unchanged")])
        == "Import 2 dives")
    #expect(ImportText.buttonLabel([try row("unchanged"), try row("skipped")]) == "Import")
    #expect(ImportText.buttonLabel([]) == "Import")
  }

  @Test func theRecordsLeaveOutTheDivesRowWhereDiveRowsExist() throws {
    let pending = try KitFixture.decode(LogbookImportRead.self, "import-pending")
    #expect(!pending.dives.isEmpty)
    #expect(!ImportText.recordRows(pending).contains { $0.collection == "dives" })
  }

  @Test func theFilesAreStagedInTheDiversTerms() {
    #expect(PendingText.fileStage(.waiting) == "Waiting to upload")
    #expect(
      PendingText.fileStage(.uploaded) == "Uploaded, waiting for the import to be finished")
    #expect(PendingText.fileStage(.refused("Too large.")) == "Refused: Too large.")
  }

  @Test func theNumberingSentenceAppearsOnlyWhereTheImportTangledIt() throws {
    let pending = try KitFixture.decode(LogbookImportRead.self, "import-pending")
    let tidy = DiveNumberingSummary(
      totalDives: 3, lowest: 1, highest: 3, missingCount: 0, duplicateCount: 0,
      outOfDateOrderCount: 0, isSequential: true)
    let shared = DiveNumberingSummary(
      totalDives: 4, lowest: 1, highest: 3, missingCount: 0, duplicateCount: 2,
      outOfDateOrderCount: 0, isSequential: false)
    #expect(
      ImportText.numberingSuggestion(before: tidy, after: shared, dives: pending.dives)
        == "Numbered #1–#3 — 2 dives share a number. Renumber them on the web, from the Dives page."
    )
    #expect(
      ImportText.numberingSuggestion(before: shared, after: shared, dives: pending.dives) == nil)
    #expect(ImportText.numberingSuggestion(before: tidy, after: nil, dives: pending.dives) == nil)
  }
}
