import Foundation
import Synchronization
import Testing

@testable import OpenDivingKit

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// The server's word on proposing, and *Withdraw* on the site's panel and on *Your Proposals*:
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

  private func primarySession(
    connectivity: any Connectivity = AlwaysReachable(), failures: Int = 0
  ) throws -> (Session, StubTransport) {
    let config = try KitFixture.text("config-commons-primary")
    let health = try KitFixture.text("health")
    let left = Mutex(failures)
    let transport = StubTransport { request in
      let failing = left.withLock { left in
        defer { left -= 1 }
        return left > 0
      }
      if failing { throw URLError(.timedOut) }
      switch StubTransport.routeKey(request) {
      case "GET config": return .json(config)
      case "GET health": return .json(health)
      default: return .json(#"{"detail":"Not Found"}"#, status: 404)
      }
    }
    let origin = ServerOrigin("https://stub.opendiving.invalid")!
    let session = Session(
      transport: transport, secrets: InMemorySecretStore([:]),
      activeOrigin: InMemoryActiveOriginStore(origin), background: NoBackgroundExecution(),
      connectivity: connectivity,
      applicationSupport: FileManager.default.temporaryDirectory.appendingPathComponent(
        "DiveSiteProposalsTests-\(UUID().uuidString)", isDirectory: true),
      userAgent: ClientHarness.userAgent)
    return (session, transport)
  }

  @Test func aLaunchWithNoRouteOffersProposingOnceARouteAppears() async throws {
    let route = RouteSwitch(available: false)
    let (session, transport) = try primarySession(connectivity: route)
    session.serverInfoRetryDelay = .seconds(3600)
    let following = Task { await session.followServerInfo() }
    while !route.isFollowed { await Task.yield() }
    #expect(!session.isCommonsPrimary)
    #expect(transport.requests.isEmpty)
    route.appear()
    await following.value
    #expect(session.isCommonsPrimary)
  }

  @Test func aFailedAskIsAskedAgain() async throws {
    let (session, transport) = try primarySession(failures: 1)
    session.serverInfoRetryDelay = .zero
    await session.followServerInfo()
    #expect(session.isCommonsPrimary)
    #expect(
      transport.requests.map(StubTransport.routeKey) == ["GET config", "GET config", "GET health"])
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

  /// `page` as the server answers `request`: the rows in the status it asks for, if it asks for
  /// one, and no more of them than a page holds.
  nonisolated private static func answer(_ page: String, to request: URLRequest) -> String {
    let query =
      request.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) }?
      .queryItems ?? []
    let status = query.first { $0.name == "status" }?.value
    let perPage = query.first { $0.name == "items_per_page" }?.value.flatMap { Int($0) } ?? 50
    var json = try! JSONSerialization.jsonObject(with: Data(page.utf8)) as! [String: Any]
    let rows = (json["data"] as! [[String: Any]]).filter {
      status == nil || $0["status"] as? String == status
    }
    json["data"] = Array(rows.prefix(perPage))
    json["total_count"] = rows.count
    json["has_more"] = rows.count > perPage
    json["items_per_page"] = perPage
    return String(decoding: try! JSONSerialization.data(withJSONObject: json), as: UTF8.self)
  }

  /// The fixture's page with the waiting row's status `status`.
  private static func page(waitingRowAs status: String) throws -> String {
    try KitFixture.text("dive-site-proposals-page").replacingOccurrences(
      of: #""status": "waiting""#, with: #""status": "\#(status)""#)
  }

  /// The proposals over a server whose waiting row turns `withdrawn` once the withdraw is in.
  private func listTransport(withdraw: StubTransport.Response) throws -> StubTransport {
    let page = try KitFixture.text("dive-site-proposals-page")
    let after = try Self.page(waitingRowAs: DiveSiteProposalStatus.withdrawn)
    let sent = Mutex(false)
    return StubTransport { request in
      switch request.route {
      case "DELETE dive-site-proposal/\(Self.proposal)":
        sent.withLock { $0 = true }
        return withdraw
      case "GET dive-site-proposals":
        return .json(Self.answer(sent.withLock { $0 } ? after : page, to: request))
      default: return .json(#"{"detail":"Not Found"}"#, status: 404)
      }
    }
  }

  private func statuses(_ list: PagedList<DiveSiteProposalRead>) -> [String] {
    list.items.map(\.status)
  }

  @Test func eachTabListsTheProposalsInItsStatus() async throws {
    let transport = try listTransport(withdraw: .json("{}"))
    let model = DiveSiteProposalsModel(session: Session.stub(transport: transport))
    await model.any.load()
    #expect(model.any.items.count == 1)
    for tab in DiveSiteProposalTab.allCases {
      await model.list(tab).load()
      #expect(statuses(model.list(tab)) == [tab.status])
    }
    let asked = transport.requests.compactMap { $0.url?.query }
    #expect(asked.filter { $0.contains("status=") }.count == 3)
    #expect(asked.contains { !$0.contains("status=") && $0.contains("items_per_page=1") })
  }

  @Test func aDiverWithNoProposalsHasNoneOfAny() async throws {
    let empty = #"{"data":[],"total_count":0,"has_more":false,"page":1,"items_per_page":1}"#
    let model = DiveSiteProposalsModel(
      session: Session.stub(
        transport: StubTransport(routes: ["GET dive-site-proposals": .json(empty)])))
    await model.any.load()
    #expect(model.any.phase == .loaded)
    #expect(model.any.items.isEmpty)
  }

  @Test func aRefreshReadsEveryTabShownAndNoOther() async throws {
    let page = try KitFixture.text("dive-site-proposals-page")
    let decided = try Self.page(waitingRowAs: DiveSiteProposalStatus.accepted)
    let isDecided = Mutex(false)
    let transport = StubTransport { request in
      switch request.route {
      case "GET dive-site-proposals":
        return .json(Self.answer(isDecided.withLock { $0 } ? decided : page, to: request))
      default: return .json(#"{"detail":"Not Found"}"#, status: 404)
      }
    }
    let model = DiveSiteProposalsModel(session: Session.stub(transport: transport))
    await model.any.load()
    await model.list(.proposed).load()
    await model.list(.accepted).load()
    isDecided.withLock { $0 = true }

    await model.refresh()
    #expect(model.list(.proposed).items.isEmpty)
    #expect(
      statuses(model.list(.accepted)) == [
        DiveSiteProposalStatus.accepted, DiveSiteProposalStatus.accepted,
      ])
    #expect(model.list(.declined).phase == .idle)
    #expect(!transport.requests.contains { $0.url?.query?.contains("status=declined") == true })
  }

  @Test func withdrawingFromTheListTakesItOffProposed() async throws {
    let transport = try listTransport(withdraw: .json(#"{"message":"Proposal withdrawn"}"#))
    let model = DiveSiteProposalsModel(session: Session.stub(transport: transport))
    await model.list(.proposed).load()
    #expect(model.list(.proposed).items.count == 1)

    await model.withdraw(UUID(uuidString: Self.proposal)!)
    #expect(model.list(.proposed).items.isEmpty)
    #expect(model.withdrawal.failure == nil)
  }

  @Test func aConflictFromTheListShowsTheSentenceAndReadsItAgain() async throws {
    let transport = try listTransport(withdraw: Self.conflict)
    let model = DiveSiteProposalsModel(session: Session.stub(transport: transport))
    await model.list(.proposed).load()

    await model.withdraw(UUID(uuidString: Self.proposal)!)
    #expect(model.withdrawal.failure == "This proposal has already been decided.")
    #expect(model.list(.proposed).items.isEmpty)
  }

  /// The proposals list over a server that answers the switch with `choice`, or, given none,
  /// with the first row as the body asked.
  private func choiceTransport(_ choice: StubTransport.Response? = nil) throws -> StubTransport {
    let page = try KitFixture.text("dive-site-proposals-page")
    let first = try KitFixture.decode(
      PaginatedListResponse<DiveSiteProposalRead>.self, "dive-site-proposals-page"
    ).data[0]
    return StubTransport { request in
      switch request.route {
      case "PATCH dive-site-proposal/\(Self.proposal)":
        if let choice { return choice }
        let body = try APICoding.decoder().decode(
          DiveSiteProposalUpdate.self, from: request.httpBody ?? Data())
        let answer =
          try JSONSerialization.jsonObject(
            with: APICoding.encoder().encode(first)) as! [String: Any]
        var shown = answer
        shown["show_proposer"] = body.showProposer
        return .json(
          String(decoding: try JSONSerialization.data(withJSONObject: shown), as: UTF8.self))
      case "GET dive-site-proposals": return .json(Self.answer(page, to: request))
      default: return .json(#"{"detail":"Not Found"}"#, status: 404)
      }
    }
  }

  @Test func theSwitchSendsTheChoiceAndTheRowShowsTheAnswer() async throws {
    let transport = try choiceTransport()
    let model = DiveSiteProposalsModel(session: Session.stub(transport: transport))
    await model.list(.proposed).load()
    let row = DiveSiteProposalSummary.row(try #require(model.list(.proposed).items.first))
    #expect(!model.showsProposer(row))

    await model.showProposer(row.proposal, true)
    let request = try #require(
      transport.requests.first { $0.route == "PATCH dive-site-proposal/\(Self.proposal)" })
    #expect(try JSONValue.parse(try #require(request.httpBody))["show_proposer"] == .bool(true))
    #expect(model.list(.proposed).items.first?.showProposer == true)
    #expect(model.showsProposer(DiveSiteProposalSummary.row(model.list(.proposed).items[0])))
    #expect(model.choiceFailure == nil)
    #expect(model.choosing == nil)
  }

  @Test func aRefusedChoicePutsTheSwitchBackAndSaysWhy() async throws {
    let transport = try choiceTransport(.json(#"{"detail":"Try later."}"#, status: 500))
    let model = DiveSiteProposalsModel(session: Session.stub(transport: transport))
    await model.list(.proposed).load()
    let row = DiveSiteProposalSummary.row(try #require(model.list(.proposed).items.first))

    await model.showProposer(row.proposal, true)
    #expect(model.choiceFailure == "Try later.")
    #expect(!model.showsProposer(DiveSiteProposalSummary.row(model.list(.proposed).items[0])))
    #expect(transport.requests.filter { $0.route == "GET dive-site-proposals" }.count == 1)
  }

  @Test func aConflictingChoiceReadsTheListAgain() async throws {
    let transport = try choiceTransport(Self.conflict)
    let model = DiveSiteProposalsModel(session: Session.stub(transport: transport))
    await model.list(.proposed).load()

    await model.showProposer(UUID(uuidString: Self.proposal)!, true)
    #expect(model.choiceFailure == "This proposal has already been decided.")
    #expect(transport.requests.filter { $0.route == "GET dive-site-proposals" }.count == 2)
  }

  @Test func aWithdrawOnTheSitesPageReachesTheListOverTheSameAccount() async throws {
    let world = try OutboxWorld()
    try await world.load()
    let page = try KitFixture.text("dive-site-proposals-page")
    let withdrawn = try Self.page(waitingRowAs: DiveSiteProposalStatus.withdrawn)
    let waiting = try site(proposal: Self.waiting)
    let gone = try site(proposal: "null")
    let sent = Mutex(false)
    world.server.override { request, _ in
      switch request.route {
      case "DELETE dive-site-proposal/\(Self.proposal)":
        sent.withLock { $0 = true }
        return .json(#"{"message":"Proposal withdrawn"}"#)
      case "GET dive-site-proposals":
        return .json(Self.answer(sent.withLock { $0 } ? withdrawn : page, to: request))
      case "GET dive-site/\(Self.siteUUID.uuidString.lowercased())":
        return .json(sent.withLock { $0 } ? gone : waiting)
      default: return nil
      }
    }
    let list = DiveSiteProposalsModel(session: world.session)
    await list.list(.proposed).load()
    let model = DiveSiteDetailModel(session: world.session, siteUUID: Self.siteUUID)
    await model.load()
    #expect(proposal(model) != nil)

    await model.withdraw(UUID(uuidString: Self.proposal)!)
    await list.list(.proposed).reloading?.value
    #expect(proposal(model) == nil)
    #expect(list.list(.proposed).items.isEmpty)
    #expect(world.server.routes.filter { $0.hasPrefix("GET dive-site/") }.count == 2)
  }
}
