import Foundation
import OpenDivingKit
import Testing

/// The notice and the list's rows, as the web's `SiteProposalNotice` and *Your Proposals* print
/// them.
struct DiveSiteProposalSummaryTests {
  private static let uuid = "01a15c10-7d3e-7b21-9a44-5e6f7a8b9c0d"

  private func state(
    kind: String = DiveSiteProposalKind.newSite, status: String,
    reason: String? = nil
  ) throws -> DiveSiteProposalState {
    let reason = reason.map { "\"\($0)\"" } ?? "null"
    return try APICoding.decoder().decode(
      DiveSiteProposalState.self,
      from: Data(
        #"{"uuid":"\#(Self.uuid)","kind":"\#(kind)","status":"\#(status)","reason":\#(reason),"#
          .appending(#""created_at":"2026-10-30T08:15:02.114522Z"}"#).utf8))
  }

  private func rows() throws -> [DiveSiteProposalSummary.Row] {
    try KitFixture.decode(
      PaginatedListResponse<DiveSiteProposalRead>.self, "dive-site-proposals-page"
    ).data.map { DiveSiteProposalSummary.row($0, in: TimeZone(identifier: "Asia/Tokyo")!) }
  }

  @Test func aWaitingNewSiteSaysItStaysPrivateAndCanBeWithdrawn() throws {
    let notice = try #require(DiveSiteProposalSummary.notice(state(status: "waiting")))
    #expect(notice.title == "Waiting for review")
    #expect(notice.message == "This site stays yours and private until a reviewer accepts it.")
    #expect(notice.withdrawable == UUID(uuidString: Self.uuid))
  }

  @Test func aWaitingChangeSaysEveryoneSeesTheSiteAsItIs() throws {
    let notice = try #require(
      DiveSiteProposalSummary.notice(state(kind: "change", status: "waiting")))
    #expect(
      notice.message
        == "Everyone, you included, sees this site as it is until a reviewer accepts your change.")
    #expect(notice.withdrawable != nil)
  }

  @Test func aDeclineCarriesItsReasonAndNoWithdraw() throws {
    let notice = try #require(
      DiveSiteProposalSummary.notice(state(status: "declined", reason: "Same reef.")))
    #expect(notice.title == "Declined")
    #expect(notice.message == "Same reef.")
    #expect(notice.withdrawable == nil)
  }

  @Test func aStatusTheSiteReadDoesNotCarryDrawsNoNotice() throws {
    #expect(DiveSiteProposalSummary.notice(try state(status: "archived")) == nil)
  }

  @Test func eachRowNamesTheSiteTheKindTheDayAndTheOutcome() throws {
    let rows = try rows()
    #expect(rows.map(\.siteName) == ["Tiger Reef", "Lighthouse Reef", "Eel Garden", "Canyon"])
    #expect(rows.map(\.kind) == ["New site", "Change", "New site", "Change"])
    #expect(rows.map(\.outcome) == ["Waiting for review", "Declined", "Accepted", "Withdrawn"])
    // Past midnight in the zone asked for, a day after the instant's UTC date.
    #expect(rows[0].date == "Nov 3, 2026")
    #expect(rows[1].reason == "The registry entry is another site's.")
    #expect(rows[0].reason == nil)
  }

  @Test func onlyAWaitingRowCanBeWithdrawn() throws {
    let rows = try rows()
    #expect(rows[0].withdrawable == UUID(uuidString: Self.uuid))
    #expect(rows.dropFirst().allSatisfy { $0.withdrawable == nil })
  }

  @Test func aKindOrAStatusThisBuildHasNotHeardOfReadsAsSent() throws {
    var page = try KitFixture.text("dive-site-proposals-page")
    page = page.replacingOccurrences(of: #""kind": "new_site""#, with: #""kind": "merge""#)
    page = page.replacingOccurrences(of: #""status": "waiting""#, with: #""status": "held""#)
    let proposal = try APICoding.decoder().decode(
      PaginatedListResponse<DiveSiteProposalRead>.self, from: Data(page.utf8)
    ).data[0]
    let row = DiveSiteProposalSummary.row(proposal)
    #expect(row.kind == "merge")
    #expect(row.outcome == "held")
    #expect(row.withdrawable == nil)
  }
}
