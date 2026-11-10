import Foundation
import Synchronization
import Testing

@testable import OpenDivingKit

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// A route the test switches, telling every subscriber when one appears.
final class RouteSwitch: Connectivity {
  private let state:
    Mutex<
      (available: Bool, appearances: Int, streams: [AsyncStream<ConnectivityMoment>.Continuation])
    >

  init(available: Bool = false) {
    state = Mutex((available, 0, []))
  }

  /// Set quietly, as a route that appeared while no screen was following it.
  var isRouteAvailable: Bool {
    get { state.withLock { $0.available } }
    set { state.withLock { $0.available = newValue } }
  }
  var routeAppearances: Int { state.withLock { $0.appearances } }

  func moments() -> AsyncStream<ConnectivityMoment> {
    let (stream, continuation) = AsyncStream<ConnectivityMoment>.makeStream()
    state.withLock { $0.streams.append(continuation) }
    return stream
  }

  /// Whether a screen is following the route yet.
  var isFollowed: Bool { state.withLock { !$0.streams.isEmpty } }

  func appear() {
    let streams = state.withLock { state in
      state.available = true
      state.appearances += 1
      return state.streams
    }
    for stream in streams { stream.yield(.routeAppeared) }
  }
}

/// The site, trip, dive and Cards screens with no route: what the phone kept shows at once, and
/// nothing is asked for until a route appears.
@MainActor
struct OfflinePagesTests {
  private let siteUUID = UUID(uuidString: "01a0a521-28c5-7e34-a572-4d7324f5033b")!
  private let tripUUID = UUID(uuidString: "01a0a57a-92c3-73d0-8f2c-e200878f9878")!
  private let contactUUID = "01a0d9e9-bdd0-793a-829f-5dc90613f84f"

  /// A phone signed in to a server that answers the site, with two species, and the trip,
  /// naming one contact.
  private func world() throws -> OutboxWorld {
    let world = try OutboxWorld()
    let site = try KitFixture.text("dive-site").replacingOccurrences(
      of: #""species_count": 0"#, with: #""species_count": 2"#)
    let trip = try KitFixture.text("trip").replacingOccurrences(
      of: #""contact_uuids": []"#, with: #""contact_uuids": ["\#(contactUUID)"]"#)
    let species = try KitFixture.text("species-life-list")
    let contact = try KitFixture.text("contact")
    let (siteRoute, tripRoute) = (
      "GET dive-site/\(siteUUID.uuidString.lowercased())",
      "GET trip/\(tripUUID.uuidString.lowercased())"
    )
    world.server.override { request, _ in
      switch request.route {
      case siteRoute: .json(site)
      case tripRoute: .json(trip)
      case "GET user/species": .json(species)
      case "GET contact/\(contactUUID)": .json(contact)
      default: nil
      }
    }
    return world
  }

  /// Runs `follow` until a route has appeared under it and every read it started has landed.
  private func followUntilRead(
    _ route: RouteSwitch, _ follow: @escaping @MainActor () async -> Void,
    landed: @escaping @MainActor () -> Bool
  ) async {
    let following = Task { await follow() }
    while !route.isFollowed { await Task.yield() }
    route.appear()
    while !landed() { await Task.yield() }
    following.cancel()
  }

  @Test func aSiteOpenedBeforeShowsItsCopyWithItsDivesAndSpeciesAndAsksForNothing() async throws {
    let first = try world()
    try await first.load()
    let online = DiveSiteDetailModel(session: first.session, siteUUID: siteUUID)
    await online.load()
    let shown = try #require(
      { if case .loaded(let site) = online.phase { site } else { nil } }())
    #expect(online.lastUpdated == nil)

    let route = RouteSwitch()
    let world = try first.relaunched(connectivity: route)
    let mark = world.server.mark
    let offline = DiveSiteDetailModel(session: world.session, siteUUID: siteUUID)
    await offline.load()
    #expect(offline.phase == .loaded(shown))
    #expect(offline.lastUpdated != nil)
    #expect(offline.dives.items.map(\.id) == online.dives.items.map(\.id))
    #expect(offline.dives.pageError == nil)
    #expect(offline.species == online.species)
    #expect(world.server.sent.count == mark)

    try await world.session.loadAccount()
    await followUntilRead(route, offline.followRoute) {
      offline.lastUpdated == nil && offline.dives.lastUpdated == nil
    }
    #expect(
      world.server.count("GET dive-site/\(siteUUID.uuidString.lowercased())", since: mark) == 1)
  }

  @Test func aSiteNeverOpenedFailsAtOnceAndLoadsWhenARouteAppears() async throws {
    let route = RouteSwitch()
    let world = try world().relaunched(connectivity: route)
    let model = DiveSiteDetailModel(session: world.session, siteUUID: siteUUID)
    await model.load()
    #expect(model.phase == .failed(.noRoute))
    #expect(world.server.sent.isEmpty)

    await followUntilRead(route, model.followRoute) {
      model.phase.isLoaded && model.dives.phase == .loaded
    }
    #expect(model.dives.items.count == 1)
  }

  @Test func aSiteTheServerNoLongerHasIsForgotten() async throws {
    let world = try world()
    try await world.load()
    await DiveSiteDetailModel(session: world.session, siteUUID: siteUUID).load()
    #expect(world.cacheA.site(siteUUID) != nil)
    #expect(
      world.cacheA.pages("site-dives-\(siteUUID.uuidString.lowercased())", of: DiveListItem.self)
        != nil)

    world.server.override { request, _ in
      request.route.hasPrefix("GET dive-site/")
        ? .json(#"{"detail":"Not Found"}"#, status: 404) : nil
    }
    let model = DiveSiteDetailModel(session: world.session, siteUUID: siteUUID)
    await model.load()
    #expect(model.phase == .notFound)
    #expect(model.lastUpdated == nil)
    #expect(world.cacheA.site(siteUUID) == nil)
    #expect(
      world.cacheA.pages("site-dives-\(siteUUID.uuidString.lowercased())", of: DiveListItem.self)
        == nil)
  }

  @Test func aTripOpenedBeforeShowsItsCopyWithItsDivesAndContacts() async throws {
    let first = try world()
    try await first.load()
    let online = TripDetailModel(session: first.session, tripUUID: tripUUID)
    await online.load()
    #expect(online.contacts.count == 1)

    let route = RouteSwitch()
    let world = try first.relaunched(connectivity: route)
    let mark = world.server.mark
    let offline = TripDetailModel(session: world.session, tripUUID: tripUUID)
    await offline.load()
    #expect(offline.phase == online.phase)
    #expect(offline.lastUpdated != nil)
    #expect(offline.contacts == online.contacts)
    #expect(offline.dives.items.map(\.id) == online.dives.items.map(\.id))
    #expect(world.server.sent.count == mark)
  }

  @Test func aTripNeverOpenedFailsAtOnceAndLoadsWhenARouteAppears() async throws {
    let route = RouteSwitch()
    let world = try world().relaunched(connectivity: route)
    let model = TripDetailModel(session: world.session, tripUUID: tripUUID)
    await model.load()
    #expect(model.phase == .failed(.noRoute))
    #expect(world.server.sent.isEmpty)

    await followUntilRead(route, model.followRoute) {
      model.phase.isLoaded && model.dives.phase == .loaded && !model.contacts.isEmpty
    }
  }

  @Test func aDiveNeverOpenedFailsAtOnceAndLoadsWhenARouteAppears() async throws {
    let route = RouteSwitch()
    let world = try OutboxWorld(connectivity: route)
    let model = DiveDetailModel(session: world.session, diveUUID: UUID())
    await model.load()
    #expect(model.phase == .failed(.noRoute))
    #expect(world.server.sent.isEmpty)

    await followUntilRead(route, model.followRoute) { model.dive != nil }
  }

  @Test func theCheckinSheetSaysItNeedsAConnectionOnlyWithNoSheetKept() async throws {
    let route = RouteSwitch()
    let world = try OutboxWorld(connectivity: route)
    let model = CheckinSheetModel(session: world.session)
    model.load()
    await model.refresh()
    #expect(model.sheet == nil)
    #expect(model.refreshError == APIError.noRoute.message)
    #expect(!model.isRefreshing)
    #expect(world.server.sent.isEmpty)
  }

  /// Runs `follow` until it is listening for routes, then stops it.
  private func followBriefly(_ route: RouteSwitch, _ follow: @escaping @MainActor () async -> Void)
    async
  {
    let following = Task { await follow() }
    while !route.isFollowed { await Task.yield() }
    following.cancel()
    await following.value
  }

  @Test func aReadThatFailedWithARouteIsNotSentAgainAtOnce() async throws {
    let route = RouteSwitch(available: true)
    let world = try OutboxWorld(connectivity: route)
    world.server.override { request, _ in
      request.route.hasPrefix("GET dive-site/") || request.route.hasPrefix("GET trip/")
        || request.route.hasPrefix("GET dive/")
        ? .json(#"{"detail":"Down"}"#, status: 503) : nil
    }
    let site = DiveSiteDetailModel(session: world.session, siteUUID: siteUUID)
    await site.load()
    await followBriefly(route, site.followRoute)
    let trip = TripDetailModel(session: world.session, tripUUID: tripUUID)
    await trip.load()
    await followBriefly(route, trip.followRoute)
    let dive = DiveDetailModel(session: world.session, diveUUID: UUID())
    await dive.load()
    await followBriefly(route, dive.followRoute)

    #expect(world.server.routes.filter { $0.hasPrefix("GET dive-site/") }.count == 1)
    #expect(world.server.routes.filter { $0.hasPrefix("GET trip/") }.count == 1)
    #expect(world.server.routes.filter { $0.hasPrefix("GET dive/") }.count == 1)
  }

  @Test func aRouteThatAppearedWhileThePageWasHiddenReadsItOnReturn() async throws {
    let route = RouteSwitch()
    let world = try world().relaunched(connectivity: route)
    let model = DiveSiteDetailModel(session: world.session, siteUUID: siteUUID)
    await model.load()
    #expect(model.phase == .failed(.noRoute))
    route.isRouteAvailable = true
    let following = Task { await model.followRoute() }
    while !route.isFollowed { await Task.yield() }
    following.cancel()
    #expect(model.phase.isLoaded)
  }

  @Test func aTripShownFromItsCopyIsReadAgainWhenARouteAppears() async throws {
    let first = try world()
    try await first.load()
    await TripDetailModel(session: first.session, tripUUID: tripUUID).load()

    let route = RouteSwitch()
    let world = try first.relaunched(connectivity: route)
    try await world.session.loadAccount()
    let model = TripDetailModel(session: world.session, tripUUID: tripUUID)
    await model.load()
    #expect(model.lastUpdated != nil)
    #expect(model.dives.lastUpdated != nil)
    await followUntilRead(route, model.followRoute) {
      model.lastUpdated == nil && model.dives.lastUpdated == nil
    }
  }

  @Test func aTripTheServerNoLongerHasIsForgotten() async throws {
    let world = try world()
    try await world.load()
    await TripDetailModel(session: world.session, tripUUID: tripUUID).load()
    #expect(world.cacheA.trip(tripUUID) != nil)

    world.server.override { request, _ in
      request.route.hasPrefix("GET trip/") ? .json(#"{"detail":"Not Found"}"#, status: 404) : nil
    }
    let model = TripDetailModel(session: world.session, tripUUID: tripUUID)
    await model.load()
    #expect(model.phase == .notFound)
    #expect(world.cacheA.trip(tripUUID) == nil)
    #expect(
      world.cacheA.pages(
        PageCacheKey<DiveListItem>.tripDives(tripUUID).name, of: DiveListItem.self) == nil)
  }

  @Test func aDeleteThatLandsLeavesNoKeptCopyOfTheRecord() async throws {
    let world = try world()
    try await world.load()
    // Each page goes before the deletes, so none reads its record back from this server, which
    // goes on answering it.
    await TripDetailModel(session: world.session, tripUUID: tripUUID).load()
    let dive = try await {
      let site = DiveSiteDetailModel(session: world.session, siteUUID: siteUUID)
      await site.load()
      return try #require(site.dives.items.first?.id)
    }()
    let keys = [
      PageCacheKey<DiveListItem>.siteDives(siteUUID).name,
      PageCacheKey<DiveListItem>.tripDives(tripUUID).name,
    ]
    for key in keys {
      #expect(world.cacheA.pages(key, of: DiveListItem.self)?.value.items.map(\.id) == [dive])
    }

    let outbox = world.outbox()
    try outbox.queue(.deleteDive(.server(dive)))
    await outbox.settled()
    for key in keys {
      #expect(world.cacheA.pages(key, of: DiveListItem.self)?.value.items.map(\.id) == [])
    }

    try outbox.queue(.deleteDiveSite(.server(siteUUID)))
    try outbox.queue(.deleteTrip(.server(tripUUID)))
    await outbox.settled()
    #expect(world.cacheA.site(siteUUID) == nil)
    #expect(world.cacheA.trip(tripUUID) == nil)
    for key in keys {
      #expect(world.cacheA.pages(key, of: DiveListItem.self) == nil)
    }
  }

  @Test func sitesAreBoundedAndTakeTheirDivesWithThem() async throws {
    let world = try OutboxWorld()
    try await world.load()
    let cache = world.cacheA
    let base =
      try JSONSerialization.jsonObject(with: KitFixture.data("dive-site")) as? [String: Any] ?? [:]
    var first: UUID?
    for index in 0...AccountCache.detailLimit {
      var object = base
      let uuid = UUID()
      object["uuid"] = uuid.uuidString.lowercased()
      let read = try APICoding.decoder().decode(
        DiveSiteRead.self, from: JSONSerialization.data(withJSONObject: object))
      if index == 0 {
        first = uuid
        cache.writePages(
          AccountCache.Pages<DiveListItem>(items: [], hasMore: false, nextPage: 2),
          key: PageCacheKey<DiveListItem>.siteDives(uuid).name)
      }
      cache.writeSite(AccountCache.Site(site: read, species: nil), fetchedAt: Date())
      if index == 0 {
        try FileManager.default.setAttributes(
          [.modificationDate: Date.distantPast],
          ofItemAtPath: cache.root.appendingPathComponent(
            "sites/\(uuid.uuidString.lowercased()).json"
          ).path)
      }
    }
    let dropped = try #require(first)
    #expect(cache.site(dropped) == nil)
    #expect(
      cache.pages(PageCacheKey<DiveListItem>.siteDives(dropped).name, of: DiveListItem.self)
        == nil)
    let folder = cache.root.appendingPathComponent("sites", isDirectory: true)
    #expect(
      try FileManager.default.contentsOfDirectory(atPath: folder.path).count
        == AccountCache.detailLimit)
  }
}
