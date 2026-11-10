import Foundation
import Synchronization
import Testing

@testable import OpenDivingKit

/// The profile's head and the diver's picture: read, kept, and shown from the phone's copy at
/// the next launch with nothing asked for.
@MainActor
struct ProfileModelTests {
  private nonisolated static let picture = Data("webp".utf8)

  private nonisolated static func answers(_ request: URLRequest) throws -> StubTransport.Response? {
    switch request.route {
    case "GET user/dive-stats": return .json(try KitFixture.text("dive-stats"))
    case "GET user/trip-places":
      return .json(#"[{"name":"Dahab, Egypt","latitude":28.5,"longitude":34.5}]"#)
    case "GET user/avatar":
      return StubTransport.Response(headers: ["Content-Type": "image/webp"], body: Self.picture)
    default: return nil
    }
  }

  private func world() async throws -> OutboxWorld {
    let world = try OutboxWorld()
    world.server.override { request, _ in try Self.answers(request) }
    try await world.load()
    return world
  }

  @Test func theHeadIsKeptAndShownAtTheNextLaunchWithNoRoute() async throws {
    let first = try await world()
    let model = ProfileModel(session: first.session)
    await model.refresh()
    #expect(model.stats?.totalDives == 532)
    #expect(model.places?.map(\.name) == ["Dahab, Egypt"])

    let world = try first.relaunched(connectivity: RouteSwitch())
    let mark = world.server.mark
    let offline = ProfileModel(session: world.session)
    await offline.refresh()
    #expect(offline.stats?.totalDives == 532)
    #expect(offline.places?.map(\.name) == ["Dahab, Egypt"])
    #expect(world.server.mark == mark)
  }

  @Test func placesThatCannotBeReadAreNone() async throws {
    let world = try OutboxWorld()
    try await world.load()
    let model = ProfileModel(session: world.session)
    await model.refresh()
    #expect(model.places == [])
    #expect(model.hero(today: .today()).mapsTheWorldWhenEmpty)
  }

  @Test func placesWhoseReadIsCutShortStayUnknown() async throws {
    let world = try OutboxWorld()
    let asked = Mutex(false)
    world.server.override { request, _ in
      guard request.route == "GET user/trip-places" else { return nil }
      asked.withLock { $0 = true }
      while !Task.isCancelled { await Task.yield() }
      throw URLError(.cancelled)
    }
    try await world.load()
    let model = ProfileModel(session: world.session)
    let shown = Task { await model.refresh() }
    while !asked.withLock({ $0 }) { await Task.yield() }
    shown.cancel()
    await shown.value
    #expect(model.places == nil)
    #expect(!model.hero(today: .today()).mapsTheWorldWhenEmpty)
  }

  @Test func thePictureIsFetchedOnceAndKept() async throws {
    let first = try await world()
    let model = AvatarModel(session: first.session)
    #expect(model.initials == "TD")
    await model.load()
    await model.load()
    #expect(model.data == Self.picture)
    #expect(first.server.count("GET user/avatar") == 1)

    let again = AvatarModel(session: try first.relaunched().session)
    #expect(again.data == Self.picture)
  }

  @Test func aPictureTheAccountNoLongerHasIsDropped() async throws {
    let first = try await world()
    await AvatarModel(session: first.session).load()
    #expect(first.cacheA.avatar != nil)

    let world = try first.relaunched()
    let user = try KitFixture.text("user").replacingOccurrences(
      of: #""avatar_sha256": "a10cf720af3b5c59bb01c5fcf34de7d5d913d095bdc03c07106d3f5489710c5c""#,
      with: #""avatar_sha256": null"#)
    world.server.override { request, _ in request.route == "GET user" ? .json(user) : nil }
    try await world.load()
    let model = AvatarModel(session: world.session)
    await model.load()
    #expect(model.data == nil)
    #expect(world.cacheA.avatar == nil)
  }
}
