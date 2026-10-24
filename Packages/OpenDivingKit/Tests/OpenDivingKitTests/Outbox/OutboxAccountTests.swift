import Foundation
import Synchronization
import Testing

@testable import OpenDivingKit

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// What starts a flush, the account load it waits for, and the writes made before the
/// account was known.
@MainActor
struct OutboxAccountTests {
  /// A phone that loaded A once and has been relaunched, the account not yet loaded.
  private func relaunchedAfterA() async throws -> OutboxWorld {
    let first = try OutboxWorld()
    try await first.load()
    return try first.relaunched()
  }

  private func failingLoads(_ world: OutboxWorld, _ failures: Int) {
    world.server.override { request, index in
      if request.route == "GET user", index < failures { throw URLError(.timedOut) }
      return nil
    }
  }

  @Test func nothingIsSentBeforeALoadReturnsAndTheLoadThatDoesFlushes() async throws {
    let world = try await relaunchedAfterA()
    let failedBefore = world.server.count("GET user")
    world.server.override { request, index in
      if request.route == "GET user", index == failedBefore { throw URLError(.timedOut) }
      return nil
    }
    let model = world.outbox()
    let item = try model.queue(.createDive(Bodies.dive()))
    #expect(item.writtenBeforeAccountKnown)
    await model.settled()
    #expect(world.server.count("POST dive") == 0)

    model.handle(.routeAppeared)
    await model.settled()
    #expect(world.server.count("POST dive") == 0)
    #expect(!world.session.accountLoaded)

    model.handle(.routeAppeared)
    await model.settled()
    #expect(world.session.accountLoaded)
    #expect(world.server.count("POST dive") == 1)
    let routes = world.server.routes
    let lastUser = try #require(routes.lastIndex(of: "GET user"))
    #expect(try #require(routes.firstIndex(of: "POST dive")) > lastUser)
    #expect(model.items.isEmpty)
  }

  @Test func aLoadThatKeepsFailingSendsNothing() async throws {
    let world = try await relaunchedAfterA()
    failingLoads(world, 100)
    let model = world.outbox()
    try model.queue(.createDive(Bodies.dive()))
    for _ in 0..<3 {
      model.handle(.becameActive)
      model.syncNow()
      await model.settled()
    }
    #expect(world.server.writes.isEmpty)
  }

  @Test func aMomentDuringALoadStartsNoSecond() async throws {
    let world = try await relaunchedAfterA()
    let before = world.server.count("GET user")
    let gate = Gate()
    world.server.override { request, _ in
      if request.route == "GET user" { await gate.pass() }
      return nil
    }
    let loader = AccountLoader(session: world.session)
    let model = OutboxModel(session: world.session, loadAccount: { await loader.loadQuietly() })
    let other = OutboxModel(session: world.session, loadAccount: { await loader.loadQuietly() })
    model.handle(.routeAppeared)
    await gate.untilArrived()
    model.handle(.becameActive)
    other.handle(.routeAppeared)
    other.syncNow()
    await gate.open()
    await model.settled()
    await other.settled()
    #expect(world.server.count("GET user") == before + 1)
    #expect(world.session.accountLoaded)
  }

  @Test func theQuietLoadRaisesNothingAndClearsWhatTheLaunchRaised() async throws {
    let world = try await relaunchedAfterA()
    let user = world.server.count("GET user")
    failingLoads(world, user + 2)
    let loader = AccountLoader(session: world.session)
    await loader.loadQuietly()
    #expect(loader.failure == nil)
    await loader.retry()
    #expect(loader.failure != nil)
    await loader.loadQuietly()
    #expect(world.session.accountLoaded)
    #expect(loader.failure == nil)
  }

  @Test func anotherAccountsLoadSendsNothingOfTheFirstsQueue() async throws {
    let first = try OutboxWorld()
    try await first.load()
    first.offline()
    let queued = first.outbox()
    try queued.queue(.createDive(Bodies.dive()))
    await queued.settled()

    let world = try first.relaunched()
    world.online()
    world.server.signIn(as: OutboxServer.accountB)
    let model = world.outbox()
    try await world.load(model)
    #expect(model.account == OutboxServer.accountB)
    let mark = world.server.mark
    model.syncNow()
    await model.settled()
    #expect(world.server.writes(since: mark).isEmpty)
    #expect(world.storesA.items().count == 1)
  }

  @Test func nothingFlushesBetweenTheCodeAndTheLoad() async throws {
    let first = try OutboxWorld()
    try await first.load()
    first.offline()
    let model = first.outbox()
    try model.queue(.createDive(Bodies.dive()))
    await model.settled()
    first.online()
    try await first.session.signOut()
    model.sessionChanged()

    first.server.signIn(as: OutboxServer.accountB)
    let request = try await first.session.requestCode(email: "b@example.com")
    _ = try await first.session.verifyCode(requestID: request, code: "123456")
    let mark = first.server.mark
    model.sessionChanged()
    try model.queue(.createDiveSite(DiveSiteCreate(name: "Canyon")))
    await model.settled()
    #expect(first.server.writes(since: mark).isEmpty)

    try await first.load(model)
    // Account A's dive is A's, and stays with it; B's site moved to B and lands.
    #expect(first.server.writes(since: mark).map(\.route) == ["POST dive-site"])
    #expect(first.storesA.items().count == 1)
  }

  @Test func aWriteMadeBeforeAnotherAccountLoadedMovesWithoutTheFirstsRecords() async throws {
    let first = try OutboxWorld()
    let before = first.outbox()
    try await first.load(before)
    first.offline()
    let site = try before.queue(.createDiveSite(DiveSiteCreate(name: "Canyon")))
    await before.settled()

    let world = try first.relaunched()
    let model = world.outbox()
    let person = RecordRef.server(UUID())
    let editedDive = RecordRef.server(UUID())
    let dive = try model.queue(.createDive(Bodies.dive(sites: [site.creates!], people: [person])))
    let newSite = try model.queue(.createDiveSite(DiveSiteCreate(name: "Reef")))
    let second = try model.queue(.createDive(Bodies.dive(2, sites: [newSite.creates!])))
    let edit = try model.queue(.updateDive(editedDive, Bodies.notes("later")))
    #expect([dive, newSite, second, edit].allSatisfy { $0.writtenBeforeAccountKnown })

    world.server.signIn(as: OutboxServer.accountB)
    try await world.session.loadAccount()
    model.sessionChanged()

    let moved = world.storesB.items()
    #expect(moved.map(\.id) == [dive.id, newSite.id, second.id, edit.id])
    #expect(moved.allSatisfy { !$0.writtenBeforeAccountKnown })
    let movedDive = try #require(moved.first)
    #expect(movedDive.operation.diveCreate?.diveSites == [])
    #expect(movedDive.operation.diveCreate?.people == [])
    #expect(movedDive.dropped == [.diveSite, .person])
    #expect(moved[2].operation.diveCreate?.diveSites == [newSite.creates!])
    #expect(moved[3].failure?.kind == .wrongAccount)
    #expect(moved[3].failure?.message.contains("Test Diver") == true)
    #expect(!moved[3].isEditable)
    #expect(world.storesA.items().map(\.id) == [site.id])
    await model.settled()
  }

  @Test func theLoadNamingTheSameAccountKeepsTheWrites() async throws {
    let world = try await relaunchedAfterA()
    let model = world.outbox()
    let item = try model.queue(.createDiveSite(DiveSiteCreate(name: "Canyon")))
    try await world.load(model)
    #expect(world.server.count("POST dive-site") == 1)
    #expect(world.storesA.items().isEmpty)
    _ = item
  }

  @Test func aDiveLoggedSignedOutCarriesNoMark() async throws {
    let first = try OutboxWorld()
    try await first.load()
    try await first.session.signOut()
    let model = first.outbox()
    let item = try model.queue(.createDive(Bodies.dive()))
    #expect(!item.writtenBeforeAccountKnown)
    #expect(first.storesA.items().map(\.id) == [item.id])
  }

  @Test func withNoAccountEverLoadedNothingOpens() async throws {
    let world = try OutboxWorld()
    let model = world.outbox()
    #expect(model.account == nil)
    #expect(throws: OutboxModel.OutboxError.noAccount) {
      try model.queue(.createDive(Bodies.dive()))
    }
  }
}
