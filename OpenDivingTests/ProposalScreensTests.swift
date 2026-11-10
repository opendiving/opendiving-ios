import OpenDivingKit
import SwiftUI
import Testing
import UIKit

@testable import OpenDiving

/// What the site's panel and *Your Proposals* are given, over the server's own answers. The
/// words themselves are the Kit's mapping's, which its tests hold.
@MainActor
struct ProposalScreensTests {
  private typealias F = OfflineFixtures

  private static let proposal =
    #"{"uuid":"01a15c10-7d3e-7b21-9a44-5e6f7a8b9c0d","kind":"new_site","status":"waiting","#
    + #""reason":null,"site":{"uuid":"01a0a521-28c5-7e34-a572-4d7324f5033b","name":"Tiger Reef"},"#
    + #""created_at":"2026-10-30T08:15:02.114522Z","decided_at":null}"#

  private static func config(primary: Bool?) -> StubTransport.Response {
    let member = primary.map { #","commons_primary":\#($0)"# } ?? ""
    return .json(#"{"registration_mode":"invite","project_operated":true\#(member)}"#)
  }

  private func session(primary: Bool?) async -> Session {
    let session = Session.stub(
      transport: StubTransport(routes: [
        "GET config": Self.config(primary: primary),
        "GET health": .json(#"{"status":"healthy"}"#),
        "GET dive-site-proposals": F.page(Self.proposal),
      ]))
    await session.loadServerInfo()
    return session
  }

  private func host(_ view: some View, session: Session) -> UIView? {
    let host = UIHostingController(rootView: NavigationStack { view }.environment(session))
    host.loadViewIfNeeded()
    host.view.layoutIfNeeded()
    return host.viewIfLoaded
  }

  @Test func theSitesMapOffersTheListOnlyWhereTheServerIsThePrimary() async {
    #expect(await session(primary: true).isCommonsPrimary)
    #expect(await !session(primary: false).isCommonsPrimary)
    #expect(await !session(primary: nil).isCommonsPrimary)
    #expect(host(SitesView(), session: await session(primary: true)) != nil)
  }

  @Test func theListsTitleIsTitleCase() {
    #expect(YourProposalsView.title == "Your Proposals")
  }

  @Test func theListIsGivenTheSiteTheOutcomeAndAWithdraw() async throws {
    let session = await session(primary: true)
    let model = DiveSiteProposalsModel(session: session)
    await model.list.load()
    let row = DiveSiteProposalSummary.row(try #require(model.list.items.first))
    #expect(row.siteName == "Tiger Reef")
    #expect(row.kind == "New site")
    #expect(row.outcome == "Waiting for review")
    #expect(row.withdrawable != nil)
    #expect(host(YourProposalsView(), session: session) != nil)
  }

  @Test func theSitesPageIsGivenTheNoticeOfAWaitingSite() async throws {
    let read = F.site.replacingOccurrences(
      of: #""owner":"account""#,
      with:
        #""proposal":{"uuid":"01a15c10-7d3e-7b21-9a44-5e6f7a8b9c0d","kind":"change","#
        + #""status":"waiting","reason":null,"created_at":"2026-10-30T08:15:02.114522Z"},"#
        + #""owner":"account""#)
    let uuid = try #require(UUID(uuidString: "01a0a521-28c5-7e34-a572-4d7324f5033b"))
    let model = DiveSiteDetailModel(
      session: Session.stub(
        transport: StubTransport(routes: [
          "GET dive-site/\(uuid.uuidString.lowercased())": .json(read),
          "GET dives": F.emptyPage,
        ])),
      siteUUID: uuid)
    await model.load()
    guard case .loaded(let site) = model.phase else {
      Issue.record("The site did not load")
      return
    }
    let notice = try #require(site.proposal.flatMap(DiveSiteProposalSummary.notice))
    #expect(notice.title == "Waiting for review")
    #expect(notice.withdrawable != nil)
  }
}
