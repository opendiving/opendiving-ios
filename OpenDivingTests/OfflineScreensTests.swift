import Foundation
import OpenDivingKit
import SwiftUI
import Synchronization
import Testing

@testable import OpenDiving

/// The flush's app-side triggers, and the tab lists offline: what the phone has shown shows
/// before a request that is never answered.
@MainActor
struct OfflineScreensTests {
  private typealias F = OfflineFixtures

  @Test func aRouteAppearingLoadsTheAccountTheLaunchCouldNotThenFlushes() async throws {
    let directory = F.directory()
    // An earlier launch, offline: the site is queued and never sent.
    let earlier = F.signedIn(
      directory,
      transport: StubTransport { request in
        if let answer = F.account(request) { return answer }
        if request.httpMethod == "POST" { throw URLError(.notConnectedToInternet) }
        return F.notFound
      })
    try await earlier.loadAccount()
    let earlierOutbox = OutboxModel(session: earlier)
    try earlierOutbox.queue(.createDiveSite(DiveSiteCreate(name: "Tiger Reef")))
    await earlierOutbox.settled()

    // This launch: the refresh works, its account load does not, then a route appears.
    let users = Counter()
    let transport = StubTransport { request in
      switch StubTransport.routeKey(request) {
      case "POST auth/refresh":
        return .json(
          #"{"access_token":"fresh","token_type":"bearer"}"#,
          headers: [
            "Set-Cookie": "refresh_token=next; HttpOnly; Max-Age=604800; Path=/; SameSite=lax"
          ])
      case "GET user":
        if users.next() == 0 {
          return .json(#"{"detail":"Internal Server Error"}"#, status: 500)
        }
        return F.user(F.accountA)
      case "GET people": return F.emptyPage
      case "POST dive-site": return .json(F.site, status: 201)
      default: return F.notFound
      }
    }
    let path = FakePath()
    let session = F.signedIn(directory, transport: transport, connectivity: path)
    let window = F.window(RootView(session: session))
    defer { window?.isHidden = true }

    let routes = { transport.requests.map(StubTransport.routeKey) }
    #expect(await F.eventually { routes().contains("GET user") && path.subscriberCount >= 2 })
    try await Task.sleep(for: .milliseconds(100))
    #expect(!session.accountLoaded)
    #expect(!routes().contains("POST dive-site"))

    path.emit(.routeAppeared)
    #expect(await F.eventually { routes().contains("POST dive-site") })
    let sent = routes()
    let loads = sent.indices.filter { sent[$0] == "GET user" }
    let send = try #require(sent.firstIndex(of: "POST dive-site"))
    #expect(loads.count >= 2)
    #expect(loads.dropFirst().first.map { $0 < send } == true)
    #expect(session.accountLoaded)
  }

  /// Loads `make`'s list online under account A, then opens it again under a session whose
  /// every request hangs, and reads what it shows before the stub is released.
  private func showsItsCopy<Item: Codable & Sendable>(
    page route: String, _ answer: StubTransport.Response, _ make: (Session) -> PagedList<Item>
  ) async throws -> (shown: Int, lastUpdated: Date?, afterRelease: Int) {
    let directory = F.directory()
    let online = F.signedIn(
      directory,
      transport: StubTransport { request in
        if let answer = F.account(request) { return answer }
        return StubTransport.routeKey(request) == route ? answer : F.notFound
      })
    try await online.loadAccount()
    await make(online).load()

    let held = HeldTransport()
    let offline = F.signedIn(directory, transport: held)
    let list = make(offline)
    let load = Task { await list.load() }
    let shown = await F.eventually { !list.items.isEmpty }
    let asked = held.routes.contains(route)
    let count = shown && asked ? list.items.count : 0
    let lastUpdated = list.lastUpdated
    held.release()
    await load.value
    return (count, lastUpdated, list.items.count)
  }

  @Test func theDivesListShowsWhatItLastLoadedBeforeTheFetchAnswers() async throws {
    let result = try await showsItsCopy(page: "GET dives", .json(DivePreviewData.page)) {
      DivesView.list($0)
    }
    #expect(result.shown == 1)
    #expect(result.lastUpdated != nil)
    #expect(result.afterRelease == 1)
  }

  @Test func theTripsListShowsWhatItLastLoadedBeforeTheFetchAnswers() async throws {
    let result = try await showsItsCopy(page: "GET trips", F.page(F.trip)) { TripsView.list($0) }
    #expect(result.shown == 1)
    #expect(result.lastUpdated != nil)
    #expect(result.afterRelease == 1)
  }

  @Test func theSitesListShowsWhatItLastLoadedBeforeTheFetchAnswers() async throws {
    let result = try await showsItsCopy(page: "GET dive-sites", F.page(F.site)) {
      SitesView.list($0)
    }
    #expect(result.shown == 1)
    #expect(result.lastUpdated != nil)
    #expect(result.afterRelease == 1)
  }

  @Test func theDivePageOpensFromTheCopyBeforeTheFetchAnswers() async throws {
    let directory = F.directory()
    let route = "GET dive/\(DivePreviewData.diveUUID.uuidString.lowercased())"
    let dive = StubTransport.Response.json(DivePreviewData.dive)
    let online = F.signedIn(
      directory,
      transport: StubTransport { request in
        if let answer = F.account(request) { return answer }
        return StubTransport.routeKey(request) == route ? dive : F.notFound
      })
    try await online.loadAccount()
    await DiveDetailModel(session: online, diveUUID: DivePreviewData.diveUUID).load()

    let held = HeldTransport()
    let model = DiveDetailModel(
      session: F.signedIn(directory, transport: held), diveUUID: DivePreviewData.diveUUID)
    let load = Task { await model.load() }
    #expect(await F.eventually { model.dive != nil })
    #expect(model.lastUpdated != nil)
    held.release()
    await load.value
    #expect(model.dive?.uuid == DivePreviewData.diveUUID)
    #expect(model.refreshError != nil)
  }
}
