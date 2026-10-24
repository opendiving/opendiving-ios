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

  @Test func theRowsReadAsTheWebsDo() throws {
    let preview = try KitFixture.decode(ImportPreview.self, "import-preview")
    let rows = ImportDiveRow.rows(
      preview.dives, members: preview.members, units: .metric, written: false)
    let first = try #require(rows.first)
    #expect(first.start == "Sep 14, 2026, 09:12 +03:00")
    #expect(first.diveTime == "49:00")
    #expect(first.depth == "24.6 m")
    #expect(first.recordedBy == "Garmin Descent Mk3")
    #expect(first.outcome == "New")
    #expect(first.opens == nil)
    #expect(ImportText.memberStatus(preview.members[0]) == ("FIT · kept on its dive", false))
    #expect(
      ImportText.memberStatus(preview.members[1])
        == ("Refused: This file is not one OpenDiving reads.", true))
  }

  @Test func theButtonNeverClaimsTheNegative() throws {
    let preview = try KitFixture.decode(ImportPreview.self, "import-preview")
    #expect(ImportText.buttonLabel(preview.dives) == "Import 1 dive")
    #expect(ImportText.buttonLabel([]) == "Import")
  }

  @Test func theNumberingSentenceAppearsOnlyWhereTheImportTangledIt() throws {
    let preview = try KitFixture.decode(ImportPreview.self, "import-preview")
    let tidy = DiveNumberingSummary(
      totalDives: 3, lowest: 1, highest: 3, missingCount: 0, duplicateCount: 0,
      outOfDateOrderCount: 0, isSequential: true)
    let shared = DiveNumberingSummary(
      totalDives: 4, lowest: 1, highest: 3, missingCount: 0, duplicateCount: 2,
      outOfDateOrderCount: 0, isSequential: false)
    #expect(
      ImportText.numberingSuggestion(before: tidy, after: shared, dives: preview.dives)
        == "Numbered #1–#3 — 2 dives share a number. Renumber them on the web, from the Dives page."
    )
    #expect(
      ImportText.numberingSuggestion(before: shared, after: shared, dives: preview.dives) == nil)
    #expect(ImportText.numberingSuggestion(before: nil, after: shared, dives: preview.dives) == nil)
  }
}
