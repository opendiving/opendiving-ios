import OpenDivingKit
import SwiftUI
import Testing
import UIKit

@testable import OpenDiving

/// What the site form and the propose flow are given. The steps and the words are the Kit's, whose
/// tests hold them; hosting checks each screen draws over the server's answers.
@MainActor
struct ProposeFlowScreensTests {
  private typealias F = OfflineFixtures

  private static let site = "01a0a521-28c5-7e34-a572-4d7324f5033b"

  private func read(owner: String = DiveSiteOwner.account, pinned: Bool = true) throws
    -> DiveSiteRead
  {
    let pin = pinned ? #""latitude":28.5,"longitude":34.5,"# : ""
    let json = """
      {"uuid":"\(Self.site)","name":"Canyon","notes":"",\(pin)
       "other_names":[],"external_ids":[],"entry_types":[],"tags":[],"dive_count":0,
       "species_count":0,"owner":"\(owner)","saved":true,
       "created_at":"2026-09-15T12:53:28.901059Z"}
      """
    return try APICoding.decoder().decode(DiveSiteRead.self, from: Data(json.utf8))
  }

  private func session(primary: Bool = true, matches: String = "[]") async -> Session {
    let session = Session.stub(
      transport: StubTransport(routes: [
        "GET config": .json(
          #"{"registration_mode":"invite","project_operated":true,"commons_primary":\#(primary)}"#),
        "GET health": .json(#"{"status":"healthy"}"#),
        "GET dive-site/\(Self.site)/commons-matches": .json(matches),
      ]))
    await session.loadServerInfo()
    return session
  }

  private func host(_ view: some View, session: Session) -> UIView? {
    let host = UIHostingController(rootView: view.environment(session))
    host.loadViewIfNeeded()
    host.view.layoutIfNeeded()
    return host.viewIfLoaded
  }

  @Test func theFormDrawsItsChoiceOnThePrimaryAndWithoutOneElsewhere() async throws {
    let site = try read()
    for primary in [true, false] {
      let session = await session(primary: primary)
      #expect(session.isCommonsPrimary == primary)
      #expect(
        DiveSiteProposalSummary.choice(site, isPrimary: session.isCommonsPrimary)
          == (primary ? .open : nil))
      #expect(
        host(NavigationStack { DiveSiteFormView(mode: .edit(site)) }, session: session) != nil)
    }
  }

  @Test func theFlowIsGivenTheReviewOnAnEmptyAnswerAndDraws() async throws {
    let session = await session()
    let flow = DiveSiteProposalFlow(session: session, site: try read())
    await flow.load()
    #expect(flow.step == .review)
    #expect(
      host(
        ProposeSiteFlowView(model: flow, ending: .constant(nil)), session: session) != nil)
  }

  @Test func theFlowsTitleIsTitleCase() {
    #expect(ProposeSiteFlowView.title == "Propose for OpenDiving Commons")
    #expect(ProposeChangeView.title == "Propose a Change")
  }

  @Test func theChangeFormDraws() async throws {
    let session = await session()
    let model = DiveSiteChangeModel(
      session: session, site: try read(owner: DiveSiteOwner.commons))
    #expect(host(NavigationStack { ProposeChangeView(model: model) }, session: session) != nil)
  }

  @Test func aSavedRecordsFormDrawsOnThePrimary() async throws {
    let session = await session()
    let site = try read(owner: DiveSiteOwner.commons)
    #expect(host(NavigationStack { DiveSiteFormView(mode: .edit(site)) }, session: session) != nil)
  }
}
