import Foundation
import Synchronization
import Testing

@testable import OpenDivingKit

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// The server's word on proposing, and *Withdraw* on the site's page and on *Your Proposals*:
/// a direct call that reads what it changed again.
@MainActor
struct DiveSiteProposalsTests {
  private static let proposal = "01a15c10-7d3e-7b21-9a44-5e6f7a8b9c0d"
  private static let waiting =
    #"{"uuid":"\#(proposal)","kind":"new_site","status":"waiting","reason":null,"#
    + #""created_at":"2026-10-30T08:15:02.114522Z"}"#
  private static let siteUUID = UUID(uuidString: "01a0a521-28c5-7e34-a572-4d7324f5033b")!
  private static let conflict = StubTransport.Response.json(
    #"{"detail":"This proposal has already been decided."}"#, status: 409)

  /// The fixture's site with `proposal` on it.
  private func site(proposal: String) throws -> String {
    try KitFixture.text("dive-site").replacingOccurrences(
      of: #""owner": "account","#, with: #""proposal": \#(proposal), "owner": "account","#)
  }

  /// A site whose proposal waits until the answer to the withdraw has gone out.
  private func siteTransport(withdraw: StubTransport.Response) throws -> StubTransport {
    let waiting = try site(proposal: Self.waiting)
    let gone = try site(proposal: "null")
    let sent = Mutex(false)
    return StubTransport { request in
      switch request.route {
      case "DELETE dive-site-proposal/\(Self.proposal)":
        sent.withLock { $0 = true }
        return withdraw
      case "GET dive-site/\(Self.siteUUID.uuidString.lowercased())":
        return .json(sent.withLock { $0 } ? gone : waiting)
      case "GET dives":
        return .json(#"{"data":[],"total_count":0,"has_more":false,"page":1,"items_per_page":100}"#)
      default: return .json(#"{"detail":"Not Found"}"#, status: 404)
      }
    }
  }

  private func proposal(_ model: DiveSiteDetailModel) -> DiveSiteProposalState? {
    guard case .loaded(let site) = model.phase else { return nil }
    return site.proposal
  }

  private func reads(_ transport: StubTransport) -> Int {
    transport.requests.filter { $0.route.hasPrefix("GET dive-site/") }.count
  }

  @Test func aConfigThatDoesNotSayReadsAsNotPrimary() async throws {
    let config = try KitFixture.text("config")
    let health = try KitFixture.text("health")
    let session = Session.stub(
      transport: StubTransport(routes: ["GET config": .json(config), "GET health": .json(health)]))
    #expect(!session.isCommonsPrimary)
    await session.loadServerInfo()
    #expect(session.server != nil)
    #expect(!session.isCommonsPrimary)
  }

  @Test func aConfigSayingFalseReadsAsNotPrimaryAndTrueAsPrimary() async throws {
    let primary = try KitFixture.text("config-commons-primary")
    let health = try KitFixture.text("health")
    for (config, expected) in [
      (
        primary.replacingOccurrences(
          of: "\"commons_primary\": true", with: "\"commons_primary\": false"), false
      ),
      (primary, true),
    ] {
      let session = Session.stub(
        transport: StubTransport(routes: ["GET config": .json(config), "GET health": .json(health)])
      )
      await session.loadServerInfo()
      #expect(session.isCommonsPrimary == expected)
    }
  }

  @Test func withdrawingReadsTheSiteAgain() async throws {
    let transport = try siteTransport(withdraw: .json(#"{"message":"Proposal withdrawn"}"#))
    let model = DiveSiteDetailModel(
      session: Session.stub(transport: transport), siteUUID: Self.siteUUID)
    await model.load()
    #expect(proposal(model)?.status == DiveSiteProposalStatus.waiting)

    await model.withdraw(UUID(uuidString: Self.proposal)!)
    #expect(proposal(model) == nil)
    #expect(model.withdrawal.failure == nil)
    #expect(model.withdrawal.withdrawing == nil)
    #expect(reads(transport) == 2)
  }

  @Test func aConflictShowsTheServersSentenceAndReadsTheSiteAgain() async throws {
    let transport = try siteTransport(withdraw: Self.conflict)
    let model = DiveSiteDetailModel(
      session: Session.stub(transport: transport), siteUUID: Self.siteUUID)
    await model.load()

    await model.withdraw(UUID(uuidString: Self.proposal)!)
    #expect(model.withdrawal.failure == "This proposal has already been decided.")
    #expect(proposal(model) == nil)
  }

  @Test func anyOtherFailureShowsItsSentenceAndLeavesThePage() async throws {
    let transport = try siteTransport(
      withdraw: .json(#"{"detail":"Try later."}"#, status: 500))
    let model = DiveSiteDetailModel(
      session: Session.stub(transport: transport), siteUUID: Self.siteUUID)
    await model.load()

    await model.withdraw(UUID(uuidString: Self.proposal)!)
    #expect(model.withdrawal.failure == "Try later.")
    #expect(reads(transport) == 1)
    #expect(proposal(model)?.status == DiveSiteProposalStatus.waiting)
  }

  /// The proposals list over a server whose first row turns `withdrawn` once the withdraw is in.
  private func listTransport(withdraw: StubTransport.Response) throws -> StubTransport {
    let page = try KitFixture.text("dive-site-proposals-page")
    let after = page.replacingOccurrences(
      of: #""status": "waiting""#, with: #""status": "withdrawn""#)
    let sent = Mutex(false)
    return StubTransport { request in
      switch request.route {
      case "DELETE dive-site-proposal/\(Self.proposal)":
        sent.withLock { $0 = true }
        return withdraw
      case "GET dive-site-proposals":
        return .json(sent.withLock { $0 } ? after : page)
      default: return .json(#"{"detail":"Not Found"}"#, status: 404)
      }
    }
  }

  @Test func withdrawingFromTheListReadsItAgain() async throws {
    let transport = try listTransport(withdraw: .json(#"{"message":"Proposal withdrawn"}"#))
    let model = DiveSiteProposalsModel(session: Session.stub(transport: transport))
    await model.list.load()
    #expect(model.list.items.count == 4)

    await model.withdraw(UUID(uuidString: Self.proposal)!)
    #expect(model.list.items.first?.status == DiveSiteProposalStatus.withdrawn)
    #expect(model.withdrawal.failure == nil)
  }

  @Test func aConflictFromTheListShowsTheSentenceAndReadsItAgain() async throws {
    let transport = try listTransport(withdraw: Self.conflict)
    let model = DiveSiteProposalsModel(session: Session.stub(transport: transport))
    await model.list.load()

    await model.withdraw(UUID(uuidString: Self.proposal)!)
    #expect(model.withdrawal.failure == "This proposal has already been decided.")
    #expect(model.list.items.first?.status == DiveSiteProposalStatus.withdrawn)
  }

  @Test func aWithdrawOnTheSitesPageReachesTheListOverTheSameAccount() async throws {
    let world = try OutboxWorld()
    try await world.load()
    let page = try KitFixture.text("dive-site-proposals-page")
    let waiting = try site(proposal: Self.waiting)
    let gone = try site(proposal: "null")
    let sent = Mutex(false)
    world.server.override { request, _ in
      switch request.route {
      case "DELETE dive-site-proposal/\(Self.proposal)":
        sent.withLock { $0 = true }
        return .json(#"{"message":"Proposal withdrawn"}"#)
      case "GET dive-site-proposals":
        return .json(
          sent.withLock { $0 }
            ? page.replacingOccurrences(
              of: #""status": "waiting""#, with: #""status": "withdrawn""#)
            : page)
      case "GET dive-site/\(Self.siteUUID.uuidString.lowercased())":
        return .json(sent.withLock { $0 } ? gone : waiting)
      default: return nil
      }
    }
    let list = DiveSiteProposalsModel(session: world.session)
    await list.list.load()
    let model = DiveSiteDetailModel(session: world.session, siteUUID: Self.siteUUID)
    await model.load()
    #expect(proposal(model) != nil)

    await model.withdraw(UUID(uuidString: Self.proposal)!)
    await list.list.reloading?.value
    #expect(proposal(model) == nil)
    #expect(list.list.items.first?.status == DiveSiteProposalStatus.withdrawn)
    #expect(world.server.routes.filter { $0.hasPrefix("GET dive-site/") }.count == 2)
  }
}
