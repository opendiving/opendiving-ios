import Foundation
import Testing

@testable import OpenDivingKit

/// The pending section's rows and the pending screen's words, over items built by hand.
struct PendingTextTests {
  private static let start = DiveTimestamp(wireValue: "2026-10-25T09:30:00+03:00")!

  private static func item(_ operation: OutboxOperation, state: OutboxItemState? = nil)
    -> OutboxItem
  {
    var item = OutboxItem(operation: operation, sequence: 1, marked: false)
    if let state { item.state = state }
    return item
  }

  private static let dive = item(
    .createDive(DiveCreate(diveNumber: 42, startTime: start, submergedTime: 2700)))
  private static let site = item(.createDiveSite(DiveSiteCreate(name: "Blue Hole")))
  private static let buddy = item(.createPerson(PersonCreate(name: "Sam")))
  private static let refused = OutboxItemState.failed(
    OutboxFailure(kind: .refused, status: 422, message: "Name is required."))

  @Test func theWritesRowNamesWhatIsWaitingInPlainWords() {
    #expect(
      PendingText.waiting([Self.buddy, Self.site, Self.dive])
        == "A dive, a site and a buddy waiting to sync")
    #expect(
      PendingText.waiting([Self.dive, Self.dive, Self.site]) == "2 dives and a site waiting to sync"
    )
    #expect(PendingText.waiting([Self.site]) == "A site waiting to sync")
  }

  @Test func theWritesRowLeavesFailuresAndADraftsOwnWritesToTheirRows() {
    let failed = Self.item(.createDiveSite(DiveSiteCreate(name: "")), state: Self.refused)
    let draft = Self.item(.createDiveDraft(DiveDraftWrite()))
    #expect(PendingText.waiting([failed, draft]) == nil)
    let discard = Self.item(.deleteDiveDraft(.server(UUID())))
    #expect(PendingText.waiting([discard, draft]) == "A discarded draft waiting to sync")
  }

  @Test func theSummaryOmitsEveryRowThatCountsNothing() {
    #expect(PendingSummary(drafts: [], items: [], notices: [], unreadable: 0, files: 0).isEmpty)
    let failed = Self.item(.createDiveSite(DiveSiteCreate(name: "")), state: Self.refused)
    let notice = OutboxNotice(kind: .dive, sentence: OutboxText.landedUnreadable)
    let draft = DiveDraftEntry(
      ref: .local(UUID()), write: DiveDraftWrite(), changedAt: Date(), hasPendingChange: true)
    let summary = PendingSummary(
      drafts: [draft, draft], items: [Self.dive, Self.site, Self.buddy, failed],
      notices: [notice], unreadable: 1, files: 2)
    #expect(
      summary.rows.map(\.text) == [
        "2 drafts", "A dive, a site and a buddy waiting to sync", "1 could not be saved",
        "Saved, but this version could not read the server's answer.",
        "Saved by another version of the app", "2 files waiting",
      ])
  }

  @Test func anItemIsNamedByItsRecord() {
    #expect(PendingText.title(of: Self.dive) == "Dive 42, Oct 25, 2026, 09:30")
    #expect(PendingText.title(of: Self.site) == "Dive site: Blue Hole")
    #expect(
      PendingText.title(of: Self.item(.updateDive(.server(UUID()), DiveUpdate())))
        == "Changes to a dive")
    #expect(
      PendingText.title(of: Self.item(.createDiveDraft(DiveDraftWrite())))
        == "Draft: Untitled draft")
  }

  @Test func aMovedItemSaysWhatItLeftOut() {
    var moved = Self.dive
    #expect(PendingText.dropped(moved) == nil)
    moved.dropped = [.diveSite]
    #expect(
      PendingText.dropped(moved)
        == "Logged before your account was known; the dive site it named was left out")
    var trip = Self.item(.createTrip(TripCreate(name: "Dahab")))
    trip.dropped = [.person, .contact]
    #expect(
      PendingText.dropped(trip)
        == "Saved before your account was known; the buddy and the contact it named were left out"
    )
  }

  @Test func theDiscardConfirmationNamesWhatItReleases() {
    #expect(
      PendingText.discardMessage(released: ["Dive 42"], withdrawn: [], logged: [])
        == "It is removed from this phone and never reaches the server. Dive 42 goes on without it."
    )
    #expect(
      PendingText.discardMessage(released: [], withdrawn: ["A", "B"], logged: ["Dive 7"])
        == "It is removed from this phone and never reaches the server. A and B are discarded"
        + " with it. Dive 7 is logged as a new dive.")
  }

  @Test func theForgetConfirmationCountsWhatHasNotReachedTheServer() {
    var summary = OutboxSummary()
    #expect(KeptText.forgetMessage(summary).contains("the dives waiting to sync"))
    summary.dives = 2
    #expect(
      KeptText.forgetMessage(summary).contains(
        "kept for offline from this phone, and 2 dives that have not been saved to the server."))
    summary = OutboxSummary()
    summary.others = 1
    #expect(
      KeptText.forgetMessage(summary).contains(
        "and 1 other change that has not been saved to the server."))
  }
}
