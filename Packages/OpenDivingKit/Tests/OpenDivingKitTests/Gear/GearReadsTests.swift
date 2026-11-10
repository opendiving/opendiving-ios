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
  private func world(queries: Queries? = nil) throws -> OutboxWorld {
    let world = try OutboxWorld()
    let items = try KitFixture.text("gear-items-page")
    let sets = try KitFixture.text("gear-sets-page")
    let item = try KitFixture.text("gear-item")
    let itemRoute = "GET gear-item/" + APIClient.wire(Self.first)
    let itemJSON = OutboxServer.with(item, uuid: APIClient.wire(Self.first))
    world.server.override { request, _ in
      guard request.route.hasPrefix("GET ") else { throw URLError(.notConnectedToInternet) }
      if request.route == "GET gear-items" {
        queries?.list.withLock { $0.append(request.url?.query ?? "") }
      }
      return switch request.route {
      case "GET gear-items": .json(items)
      case "GET gear-sets": .json(sets)
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
    while offline.items.lastUpdated != nil || offline.sets.lastUpdated != nil {
      await Task.yield()
    }
    showing.cancel()
    #expect(world.server.count("GET gear-items", since: mark) == 1)
    #expect(world.server.count("GET gear-sets", since: mark) == 1)
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
