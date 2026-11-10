import Foundation
import Synchronization
import Testing

@testable import OpenDivingKit

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// More's record pages and lists as the phone keeps them: shown at once and offline from what it
/// showed, forgotten on a 404 with the lists beside them, and the account's alone.
@MainActor
struct MoreRecordCacheTests {
  private let uuid = UUID(uuidString: "01a14b2e-0c3d-7a10-9f00-1a2b3c4d5e6f")!
  private var wire: String { uuid.uuidString.lowercased() }

  /// A phone signed in to a server that answers each of More's single reads for ``uuid``.
  private func world() throws -> OutboxWorld {
    let world = try OutboxWorld()
    let answers: [String: String] = try [
      "GET gear-item/\(wire)": OutboxServer.with(KitFixture.text("gear-item"), uuid: wire),
      "GET course/\(wire)": OutboxServer.with(KitFixture.text("course"), uuid: wire),
      "GET certification/\(wire)": OutboxServer.with(
        KitFixture.text("certification-front-only"), uuid: wire),
      "GET person/\(wire)": OutboxServer.with(KitFixture.text("person"), uuid: wire),
      "GET species/\(wire)": OutboxServer.with(KitFixture.text("species"), uuid: wire),
      "GET user/species/\(wire)": OutboxServer.with(
        KitFixture.text("species-life-list-entry"), uuid: wire),
    ]
    world.server.override { request, _ in answers[request.route].map { .json($0) } }
    return world
  }

  /// Each page kind: what the phone opened shows offline under its age, asking for nothing, and
  /// is read again once a route appears.
  private func keptOffline<Record>(
    _ page: @MainActor (Session) -> RecordPage<Record>, route: String
  ) async throws {
    let first = try world()
    try await first.load()
    let online = page(first.session)
    await online.load()
    #expect(online.phase.isLoaded)
    #expect(online.lastUpdated == nil)

    let switchable = RouteSwitch()
    let world = try first.relaunched(connectivity: switchable)
    let mark = world.server.mark
    let offline = page(world.session)
    await offline.load()
    #expect(offline.phase == online.phase)
    #expect(offline.lastUpdated != nil)
    #expect(world.server.sent.count == mark)

    try await world.session.loadAccount()
    let following = Task { await offline.followRoute() }
    while !switchable.isFollowed { await Task.yield() }
    switchable.appear()
    while offline.lastUpdated != nil { await Task.yield() }
    following.cancel()
    #expect(world.server.count(route, since: mark) == 1)
  }

  @Test func aGearItemOpenedBeforeShowsOffline() async throws {
    try await keptOffline(
      { RecordPage(session: $0, gearItem: uuid) }, route: "GET gear-item/\(wire)")
  }

  @Test func aCourseOpenedBeforeShowsOffline() async throws {
    try await keptOffline({ RecordPage(session: $0, course: uuid) }, route: "GET course/\(wire)")
  }

  @Test func aCertificationOpenedBeforeShowsOffline() async throws {
    try await keptOffline(
      { RecordPage(session: $0, certification: uuid) }, route: "GET certification/\(wire)")
  }

  @Test func aPersonOpenedBeforeShowsOffline() async throws {
    try await keptOffline({ RecordPage(session: $0, person: uuid) }, route: "GET person/\(wire)")
  }

  @Test func aSpeciesOpenedBeforeShowsOfflineWithItsHistory() async throws {
    try await keptOffline({ RecordPage(session: $0, species: uuid) }, route: "GET species/\(wire)")
    let world = try world()
    try await world.load()
    let page = RecordPage(session: world.session, species: uuid)
    await page.load()
    guard case .loaded(let shown) = page.phase, case .seen(let entry) = shown.history else {
      Issue.record("The species and its history were not read")
      return
    }
    #expect(entry.diveCount == 7)
  }

  @Test func aSpeciesNoDiveRecordsHasNoHistoryAndOneThatFailedVouchesForNone() async throws {
    let world = try world()
    try await world.load()
    let wire = wire
    let species = try OutboxServer.with(KitFixture.text("species"), uuid: wire)
    let history = Mutex(StubTransport.Response.json(#"{"detail":"Not Found"}"#, status: 404))
    world.server.override { request, _ in
      switch request.route {
      case "GET species/\(wire)": .json(species)
      case "GET user/species/\(wire)": history.withLock { $0 }
      default: nil
      }
    }
    let page = RecordPage(session: world.session, species: uuid)
    await page.load()
    #expect(Self.history(page) == .never)

    history.withLock { $0 = .json(#"{"detail":"Down"}"#, status: 503) }
    await page.refresh()
    #expect(Self.history(page) == .unknown)
  }

  private static func history(_ page: RecordPage<SpeciesPage>) -> SpeciesPage.History? {
    guard case .loaded(let shown) = page.phase else { return nil }
    return shown.history
  }

  @Test func aPageNeverOpenedFailsAtOnceAndLoadsWhenARouteAppears() async throws {
    let route = RouteSwitch()
    let world = try world().relaunched(connectivity: route)
    let page = RecordPage(session: world.session, gearItem: uuid)
    await page.load()
    #expect(page.phase == .failed(.noRoute))
    #expect(world.server.sent.isEmpty)

    let following = Task { await page.followRoute() }
    while !route.isFollowed { await Task.yield() }
    route.appear()
    while !page.phase.isLoaded { await Task.yield() }
    following.cancel()
  }

  @Test func aRecordTheServerNoLongerHasIsForgottenWithItsLists() async throws {
    let world = try world()
    try await world.load()
    await RecordPage(session: world.session, gearItem: uuid).load()
    let dives = PagedList(session: world.session, cache: .gearItemDives(uuid)) {
      client, page, perPage in
      try await client.dives(.gearItem(uuid), page: page, itemsPerPage: perPage)
    }
    await dives.load()
    let lists = KeptRecordKind<GearItemRead>.gearItem.lists(uuid)
    #expect(lists.count == 3)
    #expect(world.cacheA.record(.gearItem, uuid) != nil)
    #expect(world.cacheA.pages(lists[0], of: DiveListItem.self) != nil)

    let wire = wire
    world.server.override { request, _ in
      request.route == "GET gear-item/\(wire)"
        ? .json(#"{"detail":"Not Found"}"#, status: 404) : nil
    }
    let page = RecordPage(session: world.session, gearItem: uuid)
    await page.load()
    #expect(page.phase == .notFound)
    #expect(page.lastUpdated == nil)
    #expect(world.cacheA.record(.gearItem, uuid) == nil)
    #expect(world.cacheA.pages(lists[0], of: DiveListItem.self) == nil)
  }

  @Test func aKeptRecordIsTheAccountsAlone() async throws {
    let first = try world()
    try await first.load()
    await RecordPage(session: first.session, person: uuid).load()
    #expect(first.cacheA.record(.person, uuid) != nil)

    let route = RouteSwitch(available: true)
    let world = try first.relaunched(connectivity: route)
    world.server.signIn(as: OutboxServer.accountB)
    try await world.session.loadAccount()
    route.isRouteAvailable = false
    let page = RecordPage(session: world.session, person: uuid)
    await page.load()
    #expect(page.phase == .failed(.noRoute))
  }

  @Test func aListShowsItsKeptPagesOffline() async throws {
    let first = try world()
    let page = try KitFixture.text("gear-items-page")
    first.server.override { request, _ in request.route == "GET gear-items" ? .json(page) : nil }
    try await first.load()
    let gear = { (session: Session) in
      PagedList(session: session, cache: .gearItems, routed: true) { client, page, perPage in
        try await client.gearItems(page: page, itemsPerPage: perPage, includeArchived: true)
      }
    }
    let online = gear(first.session)
    await online.load()
    #expect(online.items.count == 3)

    let world = try first.relaunched(connectivity: RouteSwitch())
    let mark = world.server.mark
    let offline = gear(world.session)
    await offline.load()
    #expect(offline.items.map(\.uuid) == online.items.map(\.uuid))
    #expect(offline.lastUpdated != nil)
    #expect(world.server.sent.count == mark)
  }

  @Test func everyListKeepsItsPagesUnderANameOfItsOwn() {
    let other = UUID()
    let names = [
      PageCacheKey<GearItemRead>.gearItems.name, PageCacheKey<GearSetRead>.gearSets.name,
      PageCacheKey<CourseRead>.courses.name, PageCacheKey<CertificationRead>.certifications.name,
      PageCacheKey<PersonRead>.people.name, PageCacheKey<ContactRead>.contacts.name,
      PageCacheKey<SpeciesLifeListEntry>.lifeList.name,
      PageCacheKey<DiveSiteSearchRow>.yourDiveSites.name,
      PageCacheKey<DiveSiteSearchRow>.siteFinder(yours: true).name,
      PageCacheKey<DiveSiteSearchRow>.siteFinder(yours: false).name,
      PageCacheKey<DiveListItem>.dives.name, PageCacheKey<TripRead>.trips.name,
    ]
    let scoped = { (uuid: UUID) in
      [
        PageCacheKey<DiveListItem>.siteDives(uuid).name,
        PageCacheKey<DiveListItem>.tripDives(uuid).name,
        PageCacheKey<DiveListItem>.gearItemDives(uuid).name,
        PageCacheKey<DiveListItem>.courseDives(uuid).name,
        PageCacheKey<DiveListItem>.personDives(uuid).name,
        PageCacheKey<DiveListItem>.speciesDives(uuid).name,
        PageCacheKey<GearServiceScheduleRead>.gearServiceSchedules(uuid).name,
        PageCacheKey<GearServiceRecordRead>.gearServiceRecords(uuid).name,
        PageCacheKey<CertificationRead>.courseCertifications(uuid).name,
      ]
    }
    let all = names + scoped(uuid) + scoped(other)
    #expect(Set(all).count == all.count)
  }

  @Test func aDiveTheServerNoLongerHasLeavesEveryRecordsList() async throws {
    let world = try world()
    try await world.load()
    let keys = [
      PageCacheKey<DiveListItem>.gearItemDives(uuid), .courseDives(uuid), .personDives(uuid),
      .speciesDives(uuid),
    ]
    for key in keys {
      await PagedList(session: world.session, cache: key) { client, page, perPage in
        try await client.dives(.gearItem(uuid), page: page, itemsPerPage: perPage)
      }.load()
    }
    let dive = try #require(
      world.cacheA.pages(keys[0].name, of: DiveListItem.self)?.value.items.first?.id)
    world.cacheA.removeDive(dive)
    for key in keys {
      #expect(world.cacheA.pages(key.name, of: DiveListItem.self)?.value.items.isEmpty == true)
    }
  }

  @Test func aSpeciesPhotoIsKeptByItsDigestAndDrawsOffline() async throws {
    let first = try world()
    let bytes = Data([0x52, 0x49, 0x46, 0x46])
    let wire = wire
    first.server.override { request, _ in
      request.route == "GET species/\(wire)/photo"
        ? StubTransport.Response(status: 200, headers: ["Content-Type": "image/webp"], body: bytes)
        : nil
    }
    try await first.load()
    let version = "ab12"
    #expect(await SpeciesPhotos.photo(uuid, version: version, session: first.session) == bytes)
    #expect(first.cacheA.speciesPhoto(version: version) == bytes)

    let world = try first.relaunched(connectivity: RouteSwitch())
    let mark = world.server.mark
    #expect(await SpeciesPhotos.photo(uuid, version: version, session: world.session) == bytes)
    #expect(await SpeciesPhotos.photo(uuid, version: "cd34", session: world.session) == nil)
    #expect(world.server.sent.count == mark)
  }

  @Test func aVersionThatIsNotADigestIsNeverAPath() async throws {
    let world = try world()
    try await world.load()
    world.cacheA.writeSpeciesPhoto(Data([1]), version: "../avatar")
    world.cacheA.writeSpeciesPhoto(Data([1]), version: "AB12")
    #expect(world.cacheA.speciesPhoto(version: "../avatar") == nil)
    #expect(world.cacheA.speciesPhoto(version: "AB12") == nil)
    #expect(world.cacheA.avatar == nil)
  }
}
