import OpenDivingKit
import SwiftUI
import Testing

@testable import OpenDiving

private typealias F = OfflineFixtures

/// The import's screens host and draw over what the Kit gives them; their content is the Kit's
/// tests' to assert.
@MainActor
struct ImportScreensTests {
  private func draws(_ view: some View) {
    let window = F.window(NavigationStack { view }.environment(ImportPreviewData.session))
    defer { window?.isHidden = true }
    #expect(window != nil)
  }

  @Test func theReviewDrawsItsCards() {
    let pending = ImportPreviewData.pending
    #expect(
      ImportDiveCard.cards(pending.dives, applied: false, units: .metric).map(\.tap) == [
        .sheet, .sheet,
      ])
    #expect(ImportDiveCard.leavesRowsOut(pending.dives))
    draws(
      List {
        ImportReviewSections(
          pending: pending, units: .metric, choices: .constant(ImportCheckInChoices()),
          phase: .idle, onImport: {}, onDiscard: {})
      })
  }

  @Test func theResultDrawsItsCards() {
    let applied = ImportPreviewData.applied
    let uuid = UUID(uuidString: "01a20000-0000-7000-8000-000000000001")!
    #expect(
      ImportDiveCard.cards(applied.dives, applied: true, units: .metric).map(\.tap) == [
        .dive(uuid), .sheet,
      ])
    draws(List { ImportResultSections(result: applied, numbering: nil, units: .metric) {} })
  }

  @Test func eachSheetDraws() {
    let cards = ImportDiveCard.cards(
      ImportPreviewData.applied.dives, applied: true, units: .metric)
    for card in cards {
      draws(ImportDiveSheetView(sheet: card.sheet(units: .metric)))
    }
  }

  @Test func theHistoryTheDetailAndTheLogDraw() async {
    let session = ImportPreviewData.session
    let list = ImportHistorySection.list(session)
    await list.load()
    #expect(list.items.map { ImportText.counts($0.counts) } == ["1 new, 1 modified"])
    draws(List { ImportHistorySection(list: list) })
    draws(ImportDetailView(uuid: ImportPreviewData.applied.uuid))
    draws(ImportLogView(uuid: ImportPreviewData.applied.uuid, written: true))
  }

  @Test func theLogsContentIsNamed() {
    let content = ImportLogContent(ImportPreviewData.notes, written: true)
    #expect(content.dives.map(\.outcome) == ["Modified", "Skipped"])
    #expect(content.notesTruncated == "1 further note is not shown.")
  }
}
