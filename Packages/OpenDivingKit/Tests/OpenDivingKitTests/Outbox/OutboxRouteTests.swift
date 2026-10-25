import Foundation
import Testing

@testable import OpenDivingKit

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// What the queue does with no route, what a landed write tells the lists, what a failed edit
/// leaves on the dive's page, and what a 404 for a dive takes off the phone.
@MainActor
struct OutboxRouteTests {
  private static let dive = UUID(uuidString: "9c890a72-f1cb-5eef-ae82-3ed803b61f17")!

  private func dives(_ session: Session) -> PagedList<DiveListItem> {
    PagedList(session: session) { client, page, perPage in
      try await client.dives(page: page, itemsPerPage: perPage)
    }
  }

  // MARK: - No route

  @Test func withNoRouteTheAppsOwnTriggersSendNothingUntilARouteAppears() async throws {
    let route = SwitchedRoute()
    let world = try OutboxWorld(connectivity: route)
    try await world.load()
    route.isRouteAvailable = false
    let model = world.outbox()
    try model.queue(.createDive(Bodies.dive()))
    await model.settled()
    model.handle(.becameActive)
    await model.settled()
    #expect(world.server.count("POST dive") == 0)
    #expect(model.items.first?.attempted == false)
    #expect(model.items.first.map(\.isEditable) == true)

    route.isRouteAvailable = true
    model.handle(.routeAppeared)
    await model.settled()
    #expect(world.server.count("POST dive") == 1)
    #expect(model.items.isEmpty)
  }

  @Test func syncNowWithNoRouteTriesAndLeavesTheCreateUnsent() async throws {
    let route = SwitchedRoute()
    let world = try OutboxWorld(connectivity: route)
    try await world.load()
    route.isRouteAvailable = false
    world.offline()
    let model = world.outbox()
    try model.queue(.createDive(Bodies.dive()))
    model.syncNow()
    await model.settled()
    #expect(world.server.count("POST dive") == 1)
    let item = try #require(model.items.first)
    #expect(item.lastAnswer == .unreachable)
    #expect(!item.attempted)
    #expect(item.sentBody == nil)
    #expect(item.isEditable)
  }

  @Test func syncNowThatSawARouteComeAndGoCountsTheCreateAsSent() async throws {
    let route = SwitchedRoute()
    let world = try OutboxWorld(connectivity: route)
    try await world.load()
    route.isRouteAvailable = false
    world.server.override { request, _ in
      guard request.route == "POST dive" else { return nil }
      route.isRouteAvailable = true
      route.isRouteAvailable = false
      throw URLError(.networkConnectionLost)
    }
    let model = world.outbox()
    try model.queue(.createDive(Bodies.dive()))
    model.syncNow()
    await model.settled()
    let item = try #require(model.items.first)
    #expect(item.lastAnswer == .unreachable)
    #expect(item.attempted)
    #expect(item.sentBody != nil)
    #expect(!item.isEditable)
  }

  @Test func aDraftSavedWithNoRouteIsWithdrawnWhenItsDiveIsLogged() async throws {
    let route = SwitchedRoute()
    let world = try OutboxWorld(connectivity: route)
    try await world.load()
    route.isRouteAvailable = false
    let model = world.outbox(quietInterval: .milliseconds(10))
    let draft = try model.beginDraft(Bodies.draft("Canyon"))
    await model.settled()
    model.leaveDraft()
    await model.settled()

    _ = try model.logDraft(draft, Bodies.dive())
    await model.settled()
    #expect(model.items.map(\.operation) == [.createDive(Bodies.dive())])
    #expect(model.drafts.isEmpty)
    #expect(world.server.writes.isEmpty)
  }

  // MARK: - Lists

  @Test func aLandedCreateOrEditReloadsTheListsAndAPersonDoesNot() async throws {
    let world = try OutboxWorld()
    try await world.load()
    let list = dives(world.session)
    await list.load()
    let model = world.outbox()

    try model.queue(.createDive(Bodies.dive()))
    await model.settled()
    await list.reloading?.value
    #expect(world.server.count("GET dives") == 2)

    try model.queue(.updateDive(.server(Self.dive), Bodies.notes("Seen a turtle")))
    await model.settled()
    await list.reloading?.value
    #expect(world.server.count("GET dives") == 3)

    try model.queue(.createPerson(PersonCreate(name: "Ana")))
    await model.settled()
    await list.reloading?.value
    #expect(world.server.count("GET dives") == 3)
    #expect(list.phase == .loaded)
  }

  // MARK: - A failed edit

  @Test func aFailedEditNeitherShowsAsPendingNorOverlaysTheDive() async throws {
    let world = try OutboxWorld()
    try await world.load()
    world.server.override { request, index in
      request.route.hasPrefix("PATCH ") && index == 0 ? .status(422, "Notes are too long.") : nil
    }
    let model = world.outbox()
    try model.queue(.updateDive(.server(Self.dive), Bodies.notes("Lost edit")))
    await model.settled()
    #expect(model.items.first?.failure?.status == 422)

    let detail = DiveDetailModel(session: world.session, diveUUID: Self.dive)
    await detail.load()
    #expect(!detail.hasPendingEdit)
    #expect(detail.dive?.notes != "Lost edit")

    world.offline()
    try model.queue(.updateDive(.server(Self.dive), Bodies.notes("Waiting edit")))
    await model.settled()
    #expect(detail.hasPendingEdit)
    #expect(detail.dive?.notes == "Waiting edit")
  }

  // MARK: - A 404

  /// The dive opened and the Dives tab shown, so the phone holds both.
  private func shown(_ world: OutboxWorld) async -> (DiveDetailModel, PagedList<DiveListItem>) {
    let list = PagedList<DiveListItem>(session: world.session, cache: .dives) {
      client, page, size in
      try await client.dives(page: page, itemsPerPage: size)
    }
    await list.load()
    let detail = DiveDetailModel(session: world.session, diveUUID: Self.dive)
    await detail.load()
    return (detail, list)
  }

  private func cachedRows(_ world: OutboxWorld) -> [UUID]? {
    world.cacheA.pages(PageCacheKey<DiveListItem>.dives.name, of: DiveListItem.self)?.value.items
      .map(\.id)
  }

  @Test func aDiveThePageFindsGoneLeavesThePhoneAndTheListsFetchAgain() async throws {
    let world = try OutboxWorld()
    try await world.load()
    let (_, list) = await shown(world)
    #expect(cachedRows(world) == [Self.dive])
    let fetches = world.server.count("GET dives")
    let route = "GET dive/\(Self.dive.uuidString.lowercased())"
    // The list's own fetch fails, so what the cache holds is what the 404 left of it.
    world.server.override { request, _ in
      if request.route == "GET dives" { throw URLError(.timedOut) }
      return request.route == route ? .status(404, "Dive not found") : nil
    }

    let detail = DiveDetailModel(session: world.session, diveUUID: Self.dive)
    await detail.load()
    await list.reloading?.value
    #expect(detail.phase == .failed(.http(status: 404, message: "Dive not found")))
    #expect(detail.lastUpdated == nil)
    #expect(world.cacheA.dive(Self.dive) == nil)
    #expect(cachedRows(world) == [])
    #expect(world.server.count("GET dives") == fetches + 1)
  }

  @Test func anEditAnswered404TakesTheDiveOffTheOpenPageAndTheLists() async throws {
    let world = try OutboxWorld()
    try await world.load()
    let (detail, list) = await shown(world)
    let model = world.outbox()
    world.offline()
    try model.queue(.updateDive(.server(Self.dive), Bodies.notes("Edited offline")))
    await model.settled()
    #expect(detail.hasPendingEdit)

    // Deleted on the web: the server lists it no more.
    world.server.override { request, _ in
      if request.route == "GET dives" { return .emptyPage }
      return request.route.hasPrefix("PATCH ") ? .status(404, "Dive not found") : nil
    }
    let fetches = world.server.count("GET dives")
    model.handle(.routeAppeared)
    await model.settled()
    await list.reloading?.value
    #expect(detail.phase == .failed(.http(status: 404, message: "Dive not found")))
    #expect(!detail.hasPendingEdit)
    #expect(world.cacheA.dive(Self.dive) == nil)
    #expect(cachedRows(world)?.contains(Self.dive) != true)
    #expect(world.server.count("GET dives") == fetches + 1)
    #expect(list.items.isEmpty)
    let item = try #require(model.items.first)
    #expect(!item.isEditable && item.isDiscardable)
  }

  @Test func anUpdateAnswered404OffersDiscardAndNotEdit() async throws {
    let world = try OutboxWorld()
    try await world.load()
    world.server.override { request, _ in
      request.route.hasPrefix("PATCH ") ? .status(404, "Not found") : nil
    }
    let model = world.outbox()
    try model.queue(.updateDive(.server(Self.dive), Bodies.notes("Gone")))
    try model.queue(.updateGearSet(.server(UUID()), GearSetUpdate(name: "Warm water")))
    await model.settled()
    #expect(model.items.count == 2)
    #expect(model.items.allSatisfy { $0.failure?.status == 404 })
    #expect(model.items.allSatisfy { !$0.isEditable && $0.isDiscardable })
  }

  @Test func aCreateAnswered404CanStillBeEdited() async throws {
    let world = try OutboxWorld()
    try await world.load()
    world.server.override { request, _ in
      request.route == "POST dive" ? .status(404, "Dive site not found") : nil
    }
    let model = world.outbox()
    try model.queue(.createDive(Bodies.dive()))
    await model.settled()
    #expect(model.items.first?.failure?.status == 404)
    #expect(model.items.first?.isEditable == true)
  }
}
