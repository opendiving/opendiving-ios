import OpenDivingKit
import SwiftUI
import Testing

@testable import OpenDiving

private typealias F = OfflineFixtures

/// The numbering card and the renumber sheet host and draw over what the Kit gives them; their
/// content is the Kit's tests' to assert.
@MainActor
struct RenumberScreensTests {
  private func draws(_ view: some View) {
    let window = F.window(view.environment(DivePreviewData.session))
    defer { window?.isHidden = true }
    #expect(window != nil)
  }

  @Test func theCardDraws() {
    draws(DiveNumberingCard(description: "Numbered #1–#5 — 2 numbers unused."))
  }

  @Test func theSheetDrawsOnTheWholeLogAndOnAnImportsScope() {
    draws(RenumberDivesSheet())
    draws(
      RenumberDivesSheet(
        defaults: RenumberDefaults(
          startAt: 47, fromDate: CalendarDate(year: 2023, month: 1, day: 1))))
  }
}
