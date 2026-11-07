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

  @Test func aMemberSaysWhatBecameOfItsFile() throws {
    let pending = try KitFixture.decode(LogbookImportRead.self, "import-pending")
    #expect(ImportText.memberStatus(pending.members[0]) == ("FIT · kept on its dive", false))
    #expect(
      ImportText.memberStatus(pending.members[1])
        == ("Refused: This file is not one OpenDiving reads.", true))
    #expect(
      ImportText.refusedFiles(pending) == ["notes.txt: This file is not one OpenDiving reads."])
  }

  @Test func theOutcomesReadInTheDiversTerms() {
    #expect(ImportText.diveOutcome("new") == "New")
    #expect(ImportText.diveOutcome("modified") == "Modified")
    #expect(ImportText.diveOutcome("unchanged") == "Already in your logbook")
    #expect(ImportText.diveOutcome("skipped") == "Skipped")
    #expect(ImportText.diveOutcome("something_new") == "something_new")
  }

  @Test func theSummaryCountsTheRowsAndTheFirstTermNamesThem() throws {
    #expect(ImportText.summary([]) == nil)
    #expect(ImportText.summary([try row("skipped")]) == "1 skipped dive")
    #expect(
      ImportText.summary([
        try row("unchanged"), try row("new"), try row("new"), try row("modified"),
        try row("something_new"),
      ]) == "2 new dives, 1 modified, 1 unchanged, 1 something_new")
  }

  @Test func aHistoryRowCountsItsOutcomes() {
    #expect(ImportText.counts(["modified": 2, "new": 12]) == "12 new, 2 modified")
    #expect(ImportText.counts(["something_new": 1, "skipped": 3]) == "3 skipped, 1 something_new")
    #expect(ImportText.counts([:]) == "No dives")
  }

  @Test func theReviewSaysHowLongItCanWait() {
    let utc = DiveTimestamp(wireValue: "2026-11-08T11:46:38+00:00")
    let line = ImportText.reviewLine(expiresAt: utc)
    #expect(line.hasPrefix("Your logbook changes when you import. You can finish this on any"))
    #expect(line.contains(" until Nov "))
    #expect(
      ImportText.reviewLine(expiresAt: nil)
        == "Your logbook changes when you import. You can finish this on any device.")
    #expect(ImportText.appliedLine(nil) == nil)
    #expect(ImportText.appliedLine(utc)?.hasPrefix("Written to your logbook on Nov ") == true)
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
