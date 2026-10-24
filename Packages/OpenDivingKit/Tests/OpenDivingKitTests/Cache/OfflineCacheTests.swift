import Foundation
import Testing

@testable import OpenDivingKit

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// The pages and the dives the phone has shown, shown first and offline, and the lookups.
@MainActor
struct OfflineCacheTests {
  private func dives(_ session: Session) -> PagedList<DiveListItem> {
    PagedList(session: session, cache: .dives) { client, page, perPage in
      try await client.dives(page: page, itemsPerPage: perPage)
    }
  }

  @Test func aListShowsWhatItLastLoadedBeforeTheFetchAnswers() async throws {
    let first = try OutboxWorld()
    try await first.load()
    let online = dives(first.session)
    await online.load()
    #expect(online.items.count == 1)
    #expect(online.lastUpdated == nil)

    let world = try first.relaunched()
    let gate = Gate()
    world.server.override { request, _ in
      if request.route == "GET dives" { await gate.pass() }
      return nil
    }
    let offline = dives(world.session)
    let loading = Task { await offline.load() }
    await gate.untilArrived()
    #expect(offline.items.map(\.id) == online.items.map(\.id))
    #expect(offline.lastUpdated != nil)
    #expect(offline.phase == .loaded)
    await gate.open()
    await loading.value
    #expect(offline.lastUpdated == nil)
  }

  @Test func aFetchThatFailsLeavesTheCachedPageStanding() async throws {
    let first = try OutboxWorld()
    try await first.load()
    await dives(first.session).load()
    let world = try first.relaunched()
    world.server.override { request, _ in
      if request.route == "GET dives" { throw URLError(.notConnectedToInternet) }
      return nil
    }
    let list = dives(world.session)
    await list.load()
    #expect(list.items.count == 1)
    #expect(list.lastUpdated != nil)
    #expect(list.pageError != nil)
  }

  @Test func theHighestNumberFollowsThePageAndALandedCreate() async throws {
    let world = try OutboxWorld()
    try await world.load()
    await dives(world.session).load()
    #expect(world.cacheA.highestDiveNumber == 532)
    let model = world.outbox()
    try model.queue(.createDive(Bodies.dive(600)))
    await model.settled()
    #expect(world.cacheA.highestDiveNumber == 600)
    try model.queue(.createDive(Bodies.dive(10)))
    await model.settled()
    #expect(model.highestKnownDiveNumber == 600)
  }

  @Test func anotherAccountsPageBeforeTheLoadLeavesTheFirstsCacheAlone() async throws {
    let first = try OutboxWorld()
    try await first.load()
    await dives(first.session).load()
    let page = try #require(first.cacheA.pages("dives", of: DiveListItem.self))
    let highest = first.cacheA.highestDiveNumber

    let world = try first.relaunched()
    world.server.signIn(as: OutboxServer.accountB)
    let mark = world.server.mark
    let list = dives(world.session)
    await list.load()
    #expect(world.server.count("GET dives", since: mark) == 1)
    try await world.session.loadAccount()
    let after = try #require(world.cacheA.pages("dives", of: DiveListItem.self))
    #expect(after.fetchedAt == page.fetchedAt)
    #expect(world.cacheA.highestDiveNumber == highest)
    let cacheB = AccountCache(
      store: world.session.store, origin: OutboxServer.origin, account: OutboxServer.accountB)
    #expect(cacheB.pages("dives", of: DiveListItem.self) == nil)
  }

  @Test func aDiveOpenedOfflineIsTheOneLoadedOnlineAndShowsFirst() async throws {
    let first = try OutboxWorld()
    try await first.load()
    let uuid = UUID()
    let online = DiveDetailModel(session: first.session, diveUUID: uuid)
    await online.load()
    let shown = try #require(online.dive)

    let world = try first.relaunched()
    let gate = Gate()
    world.server.override { request, _ in
      if request.route == "GET dive/\(uuid.uuidString.lowercased())" { await gate.pass() }
      return nil
    }
    let offline = DiveDetailModel(session: world.session, diveUUID: uuid)
    let loading = Task { await offline.load() }
    await gate.untilArrived()
    #expect(offline.dive == shown)
    #expect(offline.lastUpdated != nil)
    await gate.open()
    await loading.value
    #expect(offline.lastUpdated == nil)
  }

  @Test func aQueuedEditIsLaidOverTheDiveUntilItIsReadBack() async throws {
    let world = try OutboxWorld()
    try await world.load()
    let uuid = UUID()
    let detail = DiveDetailModel(session: world.session, diveUUID: uuid)
    await detail.load()
    #expect(!detail.hasPendingEdit)

    world.offline()
    let model = world.outbox()
    let site = try model.queue(.createDiveSite(DiveSiteCreate(name: "New Canyon")))
    var update = Bodies.notes("Edited offline")
    update.maxDepth = .value(31.5)
    update.diveSites = [site.creates!]
    try model.queue(.updateDive(.server(uuid), update))
    await model.settled()
    #expect(detail.hasPendingEdit)
    #expect(detail.dive?.notes == "Edited offline")
    #expect(detail.dive?.maxDepth == 31.5)
    #expect(detail.dive?.diveSites.map(\.name) == ["New Canyon"])
    #expect(model.cachedDive(uuid)?.notes == "Edited offline")

    world.online()
    model.syncNow()
    await model.settled()
    #expect(!detail.hasPendingEdit)
  }

  @Test func aLandedEditStaysOnTheDiveWhenItsReadBackFails() async throws {
    let world = try OutboxWorld()
    try await world.load()
    let uuid = UUID()
    let route = "GET dive/\(uuid.uuidString.lowercased())"
    let tripID = "01a0a57a-92c3-73d0-8f2c-e200878f9878"
    var linked =
      try JSONSerialization.jsonObject(with: KitFixture.data("dive-detail")) as? [String: Any]
      ?? [:]
    linked["uuid"] = uuid.uuidString.lowercased()
    linked["trip_uuid"] = tripID
    let dive = String(decoding: try JSONSerialization.data(withJSONObject: linked), as: UTF8.self)
    let trip = try KitFixture.text("trip")
    world.server.override { request, _ in
      if request.route == route { return .json(dive) }
      return request.route == "GET trip/\(tripID)" ? .json(trip) : nil
    }
    let detail = DiveDetailModel(session: world.session, diveUUID: uuid)
    await detail.load()
    #expect(detail.trip != nil)
    #expect(world.cacheA.dive(uuid)?.value.trip != nil)

    world.server.override { request, _ in
      if request.route == route { throw URLError(.networkConnectionLost) }
      return nil
    }
    let model = world.outbox()
    var update = Bodies.notes("Edited")
    update.trip = .null
    try model.queue(.updateDive(.server(uuid), update))
    await model.settled()
    #expect(model.items.isEmpty)
    #expect(!detail.hasPendingEdit)
    #expect(detail.dive?.notes == "Edited")
    #expect(detail.dive?.tripUuid == nil)
    #expect(detail.trip == nil)
    #expect(model.cachedDive(uuid)?.notes == "Edited")
    #expect(world.cacheA.dive(uuid)?.value.trip == nil)
  }

  @Test func aDetailsLateWriteLeavesAnEditReadBackMeanwhile() async throws {
    let world = try OutboxWorld()
    try await world.load()
    let uuid = UUID()
    let route = "GET dive/\(uuid.uuidString.lowercased())"
    let tripID = "01a0a57a-92c3-73d0-8f2c-e200878f9878"
    func dive(_ notes: String) throws -> String {
      var object =
        try JSONSerialization.jsonObject(with: KitFixture.data("dive-detail")) as? [String: Any]
        ?? [:]
      object["uuid"] = uuid.uuidString.lowercased()
      object["trip_uuid"] = tripID
      object["notes"] = notes
      return String(decoding: try JSONSerialization.data(withJSONObject: object), as: UTF8.self)
    }
    let before = try dive("Before")
    let after = try dive("After")
    let gate = Gate()
    world.server.override { request, index in
      if request.route == route { return .json(index == 0 ? before : after) }
      if request.route == "GET trip/\(tripID)" { await gate.pass() }
      return nil
    }
    let detail = DiveDetailModel(session: world.session, diveUUID: uuid)
    let loading = Task { await detail.load() }
    await gate.untilArrived()
    let model = world.outbox()
    try model.queue(.updateDive(.server(uuid), Bodies.notes("After")))
    await model.settled()
    await gate.open()
    await loading.value
    #expect(world.cacheA.dive(uuid)?.value.dive.notes == "After")
    #expect(detail.dive?.notes == "After")
  }

  @Test func detailsAreBoundedToTheMostRecentlyOpened() async throws {
    let world = try OutboxWorld()
    try await world.load()
    let cache = world.cacheA
    let base =
      try JSONSerialization.jsonObject(with: KitFixture.data("dive-detail")) as? [String: Any]
      ?? [:]
    var first: UUID?
    for index in 0...AccountCache.detailLimit {
      var object = base
      let uuid = UUID()
      if index == 0 { first = uuid }
      object["uuid"] = uuid.uuidString.lowercased()
      let read = try APICoding.decoder().decode(
        DiveReadWithMixtures.self, from: JSONSerialization.data(withJSONObject: object))
      cache.writeDive(AccountCache.Dive(dive: read), fetchedAt: Date())
      if index == 0 {
        try FileManager.default.setAttributes(
          [.modificationDate: Date.distantPast],
          ofItemAtPath: cache.root.appendingPathComponent(
            "dives/\(uuid.uuidString.lowercased()).json"
          ).path)
      }
    }
    #expect(cache.dive(try #require(first)) == nil)
    let folder = cache.root.appendingPathComponent("dives", isDirectory: true)
    #expect(
      try FileManager.default.contentsOfDirectory(atPath: folder.path).count
        == AccountCache.detailLimit)
  }

  @Test func aCacheFileThatWillNotDecodeIsDroppedAndFetchedAgain() async throws {
    let world = try OutboxWorld()
    try await world.load()
    let file = world.cacheA.root.appendingPathComponent("pages/dives.json")
    try FileManager.default.createDirectory(
      at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data("not json".utf8).write(to: file)
    let list = dives(world.session)
    await list.load()
    #expect(list.items.count == 1)
    #expect(world.cacheA.pages("dives", of: DiveListItem.self)?.value.items.count == 1)
  }

  @Test func lookupsListThePhonesRecordsAfterTheServersAndFollowAResolution() async throws {
    let world = try OutboxWorld()
    let sites = try KitFixture.text("lookup-dive-sites")
    world.server.override { request, _ in
      request.route == "GET dive-sites/lookup" ? .json(sites) : nil
    }
    let model = world.outbox()
    try await world.load(model)
    let lookups = LookupsModel(session: world.session)
    let refresh = world.server.mark
    await lookups.refresh()
    let server = lookups.diveSites.count
    #expect(server > 0)
    for route in [
      "GET dive-sites/lookup", "GET trips/lookup", "GET contacts/lookup", "GET people/lookup",
      "GET courses/lookup", "GET gear-items/lookup", "GET gear-sets", "GET user/species",
      "GET dives/recent-volumes",
    ] {
      #expect(world.server.count(route, since: refresh) == 1)
    }

    world.offline()
    let site = try model.queue(.createDiveSite(DiveSiteCreate(name: "Fresh Reef")))
    await model.settled()
    #expect(lookups.diveSites.count == server + 1)
    #expect(lookups.diveSites.last?.ref == site.creates)
    #expect(LookupsModel.matching(lookups.diveSites, "fresh").map(\.ref) == [site.creates!])

    // The refresh after the create fails, so the row the landing wrote is what shows.
    world.server.override { request, _ in
      if request.route == "GET dive-sites/lookup" { throw URLError(.notConnectedToInternet) }
      return nil
    }
    model.syncNow()
    await model.settled()
    let uuid = try #require(world.server.created.last)
    #expect(lookups.diveSites.count == server + 1)
    #expect(lookups.diveSites.last?.ref == .server(uuid))
    #expect(lookups.diveSites.last?.name == "Fresh Reef")
  }

  @Test func aGearSetSavedOfflineIsListedWithItsItems() async throws {
    let world = try OutboxWorld()
    let model = world.outbox()
    try await world.load(model)
    world.offline()
    let item = try model.queue(.createGearItem(GearItemCreate(name: "Wing", type: "bcd")))
    _ = try model.queue(
      .createGearSet(GearSetCreate(name: "Warm", weight: 4, gearItems: [item.creates!])))
    let lookups = LookupsModel(session: world.session)
    #expect(lookups.gearSets.map(\.name) == ["Warm"])
    #expect(lookups.gearSets.first?.items.map(\.name) == ["Wing"])
    #expect(lookups.gearSets.first?.weight == 4)
    await model.settled()
  }
}
