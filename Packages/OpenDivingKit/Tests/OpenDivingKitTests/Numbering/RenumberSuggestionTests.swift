import Foundation
import Synchronization
import Testing

@testable import OpenDivingKit

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// The import result's offer to renumber, and the numbering card above the dives.
@MainActor
struct RenumberSuggestionTests {
  private let tidy =
    #"{"total_dives":3,"lowest":1,"highest":3,"missing_count":0,"duplicate_count":0,"out_of_date_order_count":0,"is_sequential":true}"#
  private let shared =
    #"{"total_dives":4,"lowest":1,"highest":3,"missing_count":0,"duplicate_count":2,"out_of_date_order_count":0,"is_sequential":false}"#

  private func served(numbering: String, next: StubTransport.Response? = nil) -> (
    Session, StubTransport
  ) {
    let transport = StubTransport(routes: [
      "GET dives/numbering": .json(numbering),
      "GET dives/next-number": next ?? .json(#"{"dive_number":47,"is_taken":true}"#),
    ])
    return (Session.stub(transport: transport), transport)
  }

  @Test func anImportThatTangledTheNumberingOffersToRenumberWhatItReached() async throws {
    let pending = try KitFixture.decode(LogbookImportRead.self, "import-pending")
    #expect(pending.numbering.duplicateCount == 0)
    let (session, transport) = served(numbering: shared)
    let suggestion = try #require(
      await RenumberSuggestion.read(
        after: pending, client: try session.requireClient(), offsetMinutes: 180))
    // The fixture's new dive started 2026-09-08T15:17:38+03:00.
    #expect(
      suggestion.defaults
        == RenumberDefaults(startAt: 47, fromDate: CalendarDate(year: 2026, month: 9, day: 8)))
    #expect(
      suggestion.text
        == "Numbered #1–#3 — 2 dives share a number. Renumbering from Sep 8, 2026 numbers every "
        + "dive from then on in date order.")
    let asked = try #require(transport.requests.last?.url)
    #expect(asked.query?.contains("start_time=2026-09-07T23:59:59%2B03:00") == true)
  }

  @Test func anImportThatLeftTheNumberingAsItWasOffersNothing() async throws {
    let pending = try KitFixture.decode(LogbookImportRead.self, "import-pending")
    let (session, _) = served(numbering: tidy)
    #expect(
      await RenumberSuggestion.read(after: pending, client: try session.requireClient()) == nil)
  }

  @Test func aReadThatFailsOffersNothing() async throws {
    let pending = try KitFixture.decode(LogbookImportRead.self, "import-pending")
    let (session, _) = served(
      numbering: shared, next: .json(#"{"detail":"Server error"}"#, status: 500))
    #expect(
      await RenumberSuggestion.read(after: pending, client: try session.requireClient()) == nil)
  }

  @Test func theCardSaysWhatARenumberWouldTidyAndNothingForATidyLog() async throws {
    let untidy = DiveNumberingModel(
      session: Session.stub(
        transport: StubTransport(routes: [
          "GET dives/numbering": .json(try KitFixture.text("dives-numbering"))
        ])))
    await untidy.load()
    #expect(untidy.description?.hasPrefix("Numbered #1–#215") == true)

    let tidyModel = DiveNumberingModel(session: served(numbering: tidy).0)
    await tidyModel.load()
    #expect(tidyModel.description == nil)
  }

  @Test func aCardWhoseReadFailsGoes() async throws {
    let numbering = try KitFixture.text("dives-numbering")
    let fails = Mutex(false)
    let model = DiveNumberingModel(
      session: Session.stub(
        transport: StubTransport { _ in
          if fails.withLock({ $0 }) { throw URLError(.timedOut) }
          return .json(numbering)
        }))
    await model.load()
    #expect(model.description != nil)

    fails.withLock { $0 = true }
    await model.load()
    #expect(model.description == nil)
  }
}
