import Foundation
import Synchronization
import Testing

@testable import OpenDivingKit

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// More's *Gear* and a gear item's page as the phone reads them: archived gear asked for, the
/// kept pages shown offline and read again once a route appears, and a queued delete or archive
/// showing at once.
@MainActor
struct GearReadsTests {
  /// A phone whose server answers the gear lists and the first item's page, and holds every
  /// write as if there were no route, so what is queued stays queued.
  private func world(queries: Queries? = nil, account: Hanging? = nil) throws -> OutboxWorld {
    let world = try OutboxWorld()
    let items = try KitFixture.text("gear-items-page")
    let sets = try KitFixture.text("gear-sets-page")
    let item = try KitFixture.text("gear-item")
    let schedules = try KitFixture.text("gear-service-schedules-page")
    let records = try KitFixture.text("gear-service-records-page")
    let itemRoute = "GET gear-item/" + APIClient.wire(Self.first)
    let itemJSON = OutboxServer.with(item, uuid: APIClient.wire(Self.first))
    world.server.override { request, _ in
      guard request.route.hasPrefix("GET ") else { throw URLError(.notConnectedToInternet) }
      if request.route == "GET user", let account, account.hangs.withLock({ $0 }) {
        account.hanging.withLock { $0 += 1 }
        while !Task.isCancelled { await Task.yield() }
        throw URLError(.cancelled)
      }
      if request.route == "GET gear-items" {
        queries?.list.withLock { $0.append(request.url?.query ?? "") }
      }
      return switch request.route {
      case "GET gear-items": .json(items)
      case "GET gear-sets": .json(sets)
      case "GET gear-service-schedules": .json(schedules)
      case "GET gear-service-records": .json(records)
      case itemRoute: .json(itemJSON)
      default: nil
      }
    }
    return world
  }

  /// The queries each `GET /gear-items` was sent with.
  final class Queries: Sendable {
    let list = Mutex<[String]>([])
  }

  /// Holds each `GET /user` until its task is cancelled once ``hangs`` is set.
  final class Hanging: Sendable {
    let hangs = Mutex(false)
    let hanging = Mutex(0)
  }

  /// The first item of `gear-items-page`.
  private static let first = UUID(uuidString: "01a14b2e-0c3d-7a10-9f00-1a2b3c4d5e6f")!

  @Test func theListAsksForArchivedGearToo() async throws {
    let queries = Queries()
    let world = try world(queries: queries)
    try await world.load()
    let model = GearListModel(session: world.session)
    await model.items.load()
    await model.sets.load()
    #expect(queries.list.withLock { $0 }.allSatisfy { $0.contains("include_archived=true") })
    #expect(!queries.list.withLock { $0 }.isEmpty)
    #expect(!model.items.items.isEmpty)
    #expect(!model.sets.items.isEmpty)
  }

  @Test func theListReadsEveryPageForItsHeadings() async throws {
    let world = try OutboxWorld()
    let first = try KitFixture.text("gear-items-page")
      .replacingOccurrences(of: #""has_more": false"#, with: #""has_more": true"#)
    let second = try KitFixture.text("gear-items-page")
      .replacingOccurrences(of: "01a14b2e", with: "02a14b2e")
      .replacingOccurrences(of: #""type": "regulator""#, with: #""type": "mask""#)
    world.server.override { request, _ in
      guard request.route == "GET gear-items" else { return nil }
      return .json(request.url?.query?.contains("page=2") == true ? second : first)
    }
    try await world.load()
    let model = GearListModel(session: world.session)
    let showing = Task { await model.show() }
    while model.items.items.count < 6 { await Task.yield() }
    showing.cancel()
    #expect(!model.items.hasMore)
    #expect(model.sections.map(\.title) == ["Basics", "SCUBA", GearTypeSection.other])
  }

  @Test func bothListsShowOfflineAndReadOnceARouteAppears() async throws {
    let first = try world()
    try await first.load()
    let online = GearListModel(session: first.session)
    await online.items.load()
    await online.sets.load()

    let route = RouteSwitch()
    let world = try first.relaunched(connectivity: route)
    try await world.session.loadAccount()
    let mark = world.server.mark
    let offline = GearListModel(session: world.session)
    let showing = Task { await offline.show() }
    while !route.isFollowed { await Task.yield() }
    #expect(offline.items.items.map(\.uuid) == online.items.items.map(\.uuid))
    #expect(offline.sets.items.map(\.uuid) == online.sets.items.map(\.uuid))
    #expect(offline.items.lastUpdated != nil)
    #expect(world.server.count("GET gear-items", since: mark) == 0)

    route.appear()
    while offline.items.fetchedAt != nil || offline.sets.fetchedAt != nil {
      await Task.yield()
    }
    showing.cancel()
    #expect(world.server.count("GET gear-items", since: mark) == 1)
    #expect(world.server.count("GET gear-sets", since: mark) == 1)
  }

  @Test func aPullOnAnItemsPageReadsTheAccountOnceForAllItsLists() async throws {
    let world = try world()
    try await world.load()
    let page = GearItemDetailModel(session: world.session, gearItemUUID: Self.first)
    await page.load()
    let mark = world.server.mark
    await page.refresh()
    #expect(world.server.count("GET user", since: mark) == 1)
    #expect(world.server.count("GET people", since: mark) == 1)
    for route in ["GET gear-service-schedules", "GET gear-service-records", "GET dives"] {
      #expect(world.server.count(route, since: mark) == 1, "\(route)")
    }
    #expect(page.service.schedules.phase == .loaded)
    #expect(page.service.records.phase == .loaded)
    #expect(page.dives.phase == .loaded)

    await page.refresh()
    #expect(world.server.count("GET user", since: mark) == 2)
  }

  @Test func aPullCancelledWhileTheAccountReloadsStopsTheRead() async throws {
    let account = Hanging()
    let world = try world(account: account)
    try await world.load()
    let page = GearItemDetailModel(session: world.session, gearItemUUID: Self.first)
    await page.load()
    account.hangs.withLock { $0 = true }
    let pull = Task { await page.refresh() }
    while account.hanging.withLock({ $0 }) == 0 { await Task.yield() }
    pull.cancel()
    await pull.value
    #expect(account.hanging.withLock { $0 } == 1)
    #expect(page.dives.pageError == nil)
    #expect(page.service.records.pageError == nil)
  }

  @Test func aListsOwnPullStillReadsTheAccount() async throws {
    let world = try world()
    try await world.load()
    let page = GearItemDetailModel(session: world.session, gearItemUUID: Self.first)
    await page.load()
    let mark = world.server.mark
    await page.dives.refresh()
    await page.service.refresh()
    #expect(world.server.count("GET user", since: mark) == 2)
  }

  @Test func aQueuedDeleteTakesTheRowAtOnce() async throws {
    let world = try world()
    try await world.load()
    let model = GearListModel(session: world.session)
    await model.items.load()
    #expect(model.items.items.contains { $0.uuid == Self.first })
    let outbox = world.outbox()
    try outbox.queue(.deleteGearItem(.server(Self.first)))
    #expect(!model.items.items.contains { $0.uuid == Self.first })
  }

  @Test func aQueuedArchiveShowsAsThePendingLine() async throws {
    let world = try world()
    try await world.load()
    let page = GearItemDetailModel(session: world.session, gearItemUUID: Self.first)
    await page.load()
    guard case .loaded(let item) = page.page.phase else {
      Issue.record("The item was not read")
      return
    }
    #expect(!page.page.hasPendingEdit)
    #expect(
      GearItemDetailModel.queue(GearItemDetailModel.archiveToggle(item), in: world.outbox()) == nil)
    #expect(page.page.hasPendingEdit)
  }
}
