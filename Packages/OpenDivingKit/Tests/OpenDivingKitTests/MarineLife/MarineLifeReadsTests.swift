import Foundation
import Synchronization
import Testing

@testable import OpenDivingKit

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// The life list, a species' page and *Your dive sites* ask what the web asks, keep what they
/// showed, and with no route ask nothing until one appears.
@MainActor
struct MarineLifeReadsTests {
  private let uuid = UUID(uuidString: "01a20000-0000-7000-8000-0000000000c1")!
  private var wire: String { uuid.uuidString.lowercased() }

  /// A phone signed in to a server that answers the species, its history, the life list and the
  /// account's sites, keeping each query it is sent.
  private func world(connectivity: any Connectivity = AlwaysReachable()) throws -> (
    OutboxWorld, Queries
  ) {
    let world = try OutboxWorld(connectivity: connectivity)
    let answers: [String: String] = try [
      "GET species/\(wire)": KitFixture.text("species"),
      "GET user/species/\(wire)": KitFixture.text("species-life-list-entry"),
      "GET user/species": KitFixture.text("species-life-list"),
      "GET dive-sites/search": KitFixture.text("dive-site-search"),
    ]
    let queries = Queries()
    world.server.override { request, _ in
      let items = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems
      queries.keep(items ?? [], for: request.route)
      return answers[request.route].map { .json($0) }
    }
    return (world, queries)
  }

  private static func value(_ name: String, in items: [URLQueryItem]?) -> String? {
    items?.first { $0.name == name }?.value
  }

  @Test func theLifeListAsksInPagesOfTheWebsGrid() async throws {
    let (world, queries) = try world()
    try await world.load()
    let list = PagedList.lifeList(world.session)
    await list.load()
    #expect(list.items.count == 2)
    let sent = queries["GET user/species"]
    #expect(Self.value("items_per_page", in: sent) == "24")
  }

  @Test func yourDiveSitesAsksForTheAccountsSitesWithNoViewAndNoCamera() async throws {
    let (world, queries) = try world()
    try await world.load()
    let list = PagedList.yourDiveSites(world.session)
    await list.load()
    #expect(!list.items.isEmpty)
    let sent = try #require(queries["GET dive-sites/search"])
    #expect(Self.value("my", in: sent) == "true")
    let names = Set(sent.map(\.name))
    #expect(names.isDisjoint(with: ["q", "latitude", "longitude", "south", "north", "sort"]))
  }

  @Test func aListShownBeforeShowsOfflineAndReadsAgainWhenARouteAppears() async throws {
    let (first, _) = try world()
    try await first.load()
    await PagedList.lifeList(first.session).load()

    let route = RouteSwitch()
    let world = try first.relaunched(connectivity: route)
    try await world.session.loadAccount()
    let mark = world.server.mark
    let list = PagedList.lifeList(world.session)
    let showing = Task { await list.show(following: world.session) }
    while !route.isFollowed { await Task.yield() }
    #expect(list.items.count == 2)
    #expect(list.lastUpdated != nil)
    #expect(world.server.count("GET user/species", since: mark) == 0)

    route.appear()
    while list.fetchedAt != nil { await Task.yield() }
    showing.cancel()
    #expect(world.server.count("GET user/species", since: mark) == 1)
  }

  @Test func aListNeverShownFailsAtOnceWithNoRoute() async throws {
    let (world, _) = try world(connectivity: RouteSwitch())
    try await world.load()
    let mark = world.server.mark
    let list = PagedList.yourDiveSites(world.session)
    await list.rereadIfStale()
    #expect(list.phase == .failed(.noRoute))
    #expect(world.server.count("GET dive-sites/search", since: mark) == 0)
  }

  @Test func aSpeciesPageReadsTheSpeciesItsHistoryItsDivesAndTheirSites() async throws {
    let (world, queries) = try world()
    try await world.load()
    let model = SpeciesDetailModel(session: world.session, speciesUUID: uuid)
    await model.load()
    #expect(model.page.phase.isLoaded)
    #expect(model.dives.phase == .loaded)
    #expect(model.sites.phase == .loaded)
    #expect(Self.value("species_uuid", in: queries["GET dives"]) == wire)
    let sites = queries["GET dive-sites/search"]
    #expect(Self.value("my", in: sites) == "true")
    #expect(Self.value("species_uuid", in: sites) == wire)
  }

  @Test func aSpeciesPageNeverShownAsksNothingUntilARouteAppears() async throws {
    let route = RouteSwitch()
    let (world, _) = try world(connectivity: route)
    try await world.load()
    let mark = world.server.mark
    let model = SpeciesDetailModel(session: world.session, speciesUUID: uuid)
    await model.load()
    #expect(model.page.phase == .failed(.noRoute))
    #expect(world.server.count("GET species/\(wire)", since: mark) == 0)

    let following = Task { await model.followRoute() }
    while !route.isFollowed { await Task.yield() }
    route.appear()
    while model.dives.phase != .loaded { await Task.yield() }
    following.cancel()
    #expect(model.page.phase.isLoaded)
    #expect(world.server.count("GET species/\(wire)", since: mark) == 1)
  }

  @Test func aPhotoThePageCouldNotHaveIsAskedForWhenARouteAppears() async throws {
    let (first, _) = try world()
    try await first.load()
    await SpeciesDetailModel(session: first.session, speciesUUID: uuid).page.load()

    let route = RouteSwitch()
    let world = try first.relaunched(connectivity: route)
    try await world.session.loadAccount()
    let bytes = Data([0x52, 0x49, 0x46, 0x46])
    let wire = wire
    let species = try KitFixture.text("species")
    world.server.override { request, _ in
      switch request.route {
      case "GET species/\(wire)": .json(species)
      case "GET species/\(wire)/photo":
        StubTransport.Response(status: 200, headers: ["Content-Type": "image/webp"], body: bytes)
      default: nil
      }
    }
    let model = SpeciesDetailModel(session: world.session, speciesUUID: uuid)
    await model.load()
    #expect(model.page.phase.isLoaded)
    #expect(model.photo == nil)

    let following = Task { await model.followRoute() }
    while !route.isFollowed { await Task.yield() }
    route.appear()
    while model.photo == nil { await Task.yield() }
    following.cancel()
    #expect(model.photo == bytes)
  }

  @Test func aPhotoAskedForTwiceWhileOnItsWayIsFetchedOnce() async throws {
    let (world, _) = try world()
    try await world.load()
    let wire = wire
    let species = try KitFixture.text("species")
    let gate = Gate()
    world.server.override { request, _ in
      switch request.route {
      case "GET species/\(wire)": return .json(species)
      case "GET species/\(wire)/photo":
        await gate.pass()
        return StubTransport.Response(
          status: 200, headers: ["Content-Type": "image/webp"], body: Data([1, 2, 3]))
      default: return nil
      }
    }
    let model = SpeciesDetailModel(session: world.session, speciesUUID: uuid)
    await model.page.load()
    let first = Task { await model.loadPhoto() }
    await gate.untilArrived()
    await model.loadPhoto()
    await gate.open()
    await first.value
    #expect(model.photo == Data([1, 2, 3]))
    #expect(world.server.count("GET species/\(wire)/photo") == 1)
  }
}

/// The query each route was last sent.
private final class Queries: Sendable {
  private let state = Mutex<[String: [URLQueryItem]]>([:])

  func keep(_ items: [URLQueryItem], for route: String) {
    state.withLock { $0[route] = items }
  }

  subscript(route: String) -> [URLQueryItem]? { state.withLock { $0[route] } }
}
