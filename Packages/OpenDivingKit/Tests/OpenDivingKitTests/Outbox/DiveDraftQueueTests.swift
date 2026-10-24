import Foundation
import Testing

@testable import OpenDivingKit

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// Dive drafts through the queue: coalesced changes, logs and discards, the drafts list and
/// what the flush reads back.
@MainActor
struct DiveDraftQueueTests {
  private let landed = UUID(uuidString: "01a14b2e-0c3d-7a10-9f00-aa2b3c4d5e6f")!

  /// A world whose drafts list holds one landed draft, loaded into the cache.
  private func withLandedDraft() async throws -> (OutboxWorld, OutboxModel) {
    let world = try OutboxWorld()
    world.server.holdDrafts([landed])
    let model = world.outbox()
    try await world.load(model)
    #expect(model.drafts.map(\.ref) == [.server(landed)])
    return (world, model)
  }

  private func patches(_ world: OutboxWorld, since mark: Int = 0) -> [OutboxServer.Sent] {
    world.server.writes(since: mark).filter { $0.route.hasPrefix("PATCH dive-draft") }
  }

  @Test func fiveChangesOfflineAreOneUpdate() async throws {
    let (world, model) = try await withLandedDraft()
    world.offline()
    for index in 1...5 {
      try model.saveDraft(.server(landed), Bodies.draft("change \(index)"))
    }
    model.leaveDraft()
    await model.settled()
    #expect(model.items.count == 1)
    #expect(model.drafts.first?.write.values.notes == "change 5")
    #expect(model.drafts.first?.hasPendingChange == true)

    world.online()
    let mark = world.server.mark
    model.handle(.routeAppeared)
    await model.settled()
    let sent = patches(world, since: mark)
    #expect(sent.count == 1)
    #expect((sent.first?.json["values"] as? [String: Any])?["notes"] as? String == "change 5")
  }

  @Test func changesOnlineGoOnceAfterTheQuietInterval() async throws {
    let world = try OutboxWorld()
    world.server.holdDrafts([landed])
    let model = world.outbox(quietInterval: .milliseconds(300))
    try await world.load(model)
    for index in 1...5 {
      try model.saveDraft(.server(landed), Bodies.draft("change \(index)"))
    }
    try await Task.sleep(for: .milliseconds(50))
    #expect(patches(world).isEmpty)
    await model.settled()
    #expect(patches(world).count == 1)
  }

  @Test func aDraftNeverSentIsLoggedAsOneDiveAndNoDraftRequest() async throws {
    let world = try OutboxWorld()
    let model = world.outbox()
    try await world.load(model)
    world.offline()
    let draft = try model.beginDraft(Bodies.draft("a"))
    try model.saveDraft(draft, Bodies.draft("b"))
    #expect(model.items.count == 1)
    world.online()
    let mark = world.server.mark
    try model.logDraft(draft, Bodies.dive())
    #expect(model.drafts.isEmpty)
    await model.settled()
    #expect(world.server.writes(since: mark).map(\.route) == ["POST dive"])
  }

  @Test func aDraftWhoseCreateWasLostIsCreatedAgainUnderItsKeyThenLogged() async throws {
    let world = try OutboxWorld()
    let model = world.outbox()
    try await world.load(model)
    world.offline()
    let draft = try model.beginDraft(Bodies.draft("a"))
    model.leaveDraft()
    await model.settled()
    try model.saveDraft(draft, Bodies.draft("b"))
    #expect(model.items.count == 2)
    #expect(model.items[1].operation == .updateDiveDraft(draft, Bodies.draft("b")))
    try model.logDraft(draft, Bodies.dive())
    #expect(model.items.count == 2)

    world.online()
    let mark = world.server.mark
    model.syncNow()
    await model.settled()
    let writes = world.server.writes(since: mark)
    #expect(writes.count == 2)
    #expect(writes[0].route == "POST dive-draft")
    #expect(writes[0].key == world.server.sent.first { $0.route == "POST dive-draft" }?.key)
    let created = world.server.created[0].uuidString.lowercased()
    #expect(writes[1].route == "POST dive-draft/\(created)/dive")
  }

  @Test func aDraftWhoseCreateCameBackGoneIsLoggedAsAPlainDive() async throws {
    let world = try OutboxWorld()
    let model = world.outbox()
    try await world.load(model)
    world.offline()
    let draft = try model.beginDraft(Bodies.draft("a"))
    model.leaveDraft()
    await model.settled()
    try model.logDraft(draft, Bodies.dive())
    let log = try #require(model.items.last)

    world.server.override { request, _ in
      request.route == "POST dive-draft" ? .status(410, "Gone.") : nil
    }
    let mark = world.server.mark
    model.syncNow()
    await model.settled()
    let writes = world.server.writes(since: mark)
    #expect(writes.map(\.route) == ["POST dive-draft", "POST dive"])
    #expect(writes[1].key == log.idempotencyKey.uuidString.lowercased())
    #expect(model.items.isEmpty)
  }

  @Test func aLandedDraftIsLoggedByTheLogRouteAndLeavesTheCache() async throws {
    let (world, model) = try await withLandedDraft()
    let mark = world.server.mark
    try model.logDraft(.server(landed), Bodies.dive())
    #expect(model.drafts.isEmpty)
    await model.settled()
    #expect(
      world.server.writes(since: mark).map(\.route) == [
        "POST dive-draft/\(landed.uuidString.lowercased())/dive"
      ])
    #expect(world.cacheA.diveDrafts?.value.contains { $0.uuid == landed } != true)
  }

  @Test func aDraftWithItsLogQueuedIsNotOfferedAfterARefresh() async throws {
    let (world, model) = try await withLandedDraft()
    world.offline()
    try model.logDraft(.server(landed), Bodies.dive())
    await model.settled()
    await model.refreshDrafts()
    #expect(world.cacheA.diveDrafts?.value.map(\.uuid) == [landed])
    #expect(model.drafts.isEmpty)
  }

  @Test func discardingADraftNeverSentSendsNothing() async throws {
    let world = try OutboxWorld()
    let model = world.outbox()
    try await world.load(model)
    let mark = world.server.mark
    let draft = try model.beginDraft(Bodies.draft("a"))
    try model.discardDraft(draft)
    await model.settled()
    #expect(world.server.writes(since: mark).isEmpty)
    #expect(model.items.isEmpty)
    #expect(model.drafts.isEmpty)
  }

  @Test func aDraftGoneFromTheServerEmptiesItsUpdate() async throws {
    let (world, model) = try await withLandedDraft()
    world.server.override { request, _ in
      request.route.hasPrefix("PATCH dive-draft") ? .status(404, "Dive draft not found") : nil
    }
    try model.saveDraft(.server(landed), Bodies.draft("late"))
    model.leaveDraft()
    await model.settled()
    #expect(model.items.isEmpty)
    #expect(model.notices.map(\.sentence) == [OutboxText.draftGone])
  }

  @Test func aLogOfADraftGoneFromTheServerBecomesADiveUnderItsKey() async throws {
    let (world, model) = try await withLandedDraft()
    world.server.override { request, _ in
      request.route.hasSuffix("/dive") ? .status(404, "Dive draft not found") : nil
    }
    let mark = world.server.mark
    try model.logDraft(.server(landed), Bodies.dive())
    let key = try #require(model.items.first?.idempotencyKey).uuidString.lowercased()
    await model.settled()
    let writes = world.server.writes(since: mark)
    #expect(writes.map(\.route).last == "POST dive")
    #expect(writes.allSatisfy { $0.key == key })
    #expect(model.items.isEmpty)
  }

  @Test func theFlushReadsBackEveryDiveAndDraftItWrote() async throws {
    let (world, model) = try await withLandedDraft()
    let dive = UUID()
    let mark = world.server.mark
    try model.queue(.updateDive(.server(dive), Bodies.notes("x")))
    try model.queue(.createDive(Bodies.dive(7)))
    try model.saveDraft(.server(landed), Bodies.draft("y"))
    model.leaveDraft()
    await model.settled()
    let routes = Array(world.server.routes.dropFirst(mark))
    let created = world.server.created.last!.uuidString.lowercased()
    #expect(routes.filter { $0 == "GET dive/\(dive.uuidString.lowercased())" }.count == 1)
    #expect(routes.filter { $0 == "GET dive/\(created)" }.count == 1)
    #expect(routes.filter { $0 == "GET dive-draft/\(landed.uuidString.lowercased())" }.count == 1)
    #expect(world.cacheA.dive(dive) != nil)
  }

  @Test func aReadBackLeavesADraftWithAChangeStillQueued() async throws {
    let world = try OutboxWorld()
    world.server.holdDrafts([landed])
    let model = world.outbox(quietInterval: .seconds(30))
    try await world.load(model)
    let gate = Gate()
    world.server.override { request, index in
      if request.route.hasPrefix("GET dive-draft/"), index == 0 { await gate.pass() }
      return nil
    }
    try model.saveDraft(.server(landed), Bodies.draft("first"))
    model.leaveDraft()
    await gate.untilArrived()
    try model.saveDraft(.server(landed), Bodies.draft("second"))
    await gate.open()
    let hub = OutboxHub.hub(
      for: world.session.store.directory(for: OutboxServer.origin, account: OutboxServer.accountA))
    await hub.flush?.value
    #expect(model.drafts.first?.write.values.notes == "second")
    #expect(model.drafts.first?.hasPendingChange == true)

    model.leaveDraft()
    await model.settled()
    #expect(world.cacheA.diveDrafts?.value.first { $0.uuid == landed }?.values.notes == "second")
  }

  @Test func aLocalDraftIsListedAndKeepsItsStateOnceLanded() async throws {
    let world = try OutboxWorld()
    let model = world.outbox()
    try await world.load(model)
    let draft = try model.beginDraft(Bodies.draft("a"))
    #expect(model.drafts.map(\.ref) == [draft])
    model.leaveDraft()
    await model.settled()
    let created = try #require(world.server.created.first)
    #expect(model.drafts.map(\.ref) == [.server(created)])
    // The form still holds the local ref; its next change reaches the landed draft.
    try model.saveDraft(draft, Bodies.draft("b"))
    #expect(model.items.first?.operation == .updateDiveDraft(.server(created), Bodies.draft("b")))
    await model.settled()
  }
}
