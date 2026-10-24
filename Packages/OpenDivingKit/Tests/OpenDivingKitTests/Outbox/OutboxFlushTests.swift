import Foundation
import Testing

@testable import OpenDivingKit

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// The queue on disk, its order, and how each answer is sorted.
@MainActor
struct OutboxFlushTests {
  @Test func queuedItemsAreTheSameAfterARelaunch() async throws {
    let world = try OutboxWorld()
    try await world.load()
    world.offline()
    let model = world.outbox()
    let site = try model.queue(.createDiveSite(DiveSiteCreate(name: "Canyon")))
    let dive = try model.queue(.createDive(Bodies.dive(sites: [site.creates!])))
    await model.settled()

    let again = try world.relaunched()
    let reopened = again.outbox()
    #expect(reopened.items.map(\.id) == [site.id, dive.id])
    #expect(reopened.items.map(\.idempotencyKey) == [site.idempotencyKey, dive.idempotencyKey])
    #expect(reopened.items.map(\.operation) == [site.operation, dive.operation])
  }

  @Test func anItemFoundInFlightIsRetriedOnceWithItsKeyAndItsBytes() async throws {
    let world = try OutboxWorld()
    try await world.load()
    world.offline()
    let model = world.outbox()
    var item = try model.queue(.createDive(Bodies.dive()))
    await model.settled()
    // As the phone left it when it was killed during the send.
    let bytes = Data(
      #"{"dive_number":1,"start_time":"2026-10-20T10:00:00+03:00","submerged_time":3000}"#.utf8)
    item.state = .inFlight
    item.attempted = true
    item.sentBody = bytes
    try world.storesA.save(item)

    let again = try world.relaunched()
    try await again.session.loadAccount()
    again.online()
    let reopened = again.outbox()
    #expect(reopened.items.first?.isPending == true)
    let before = again.server.count("POST dive")
    reopened.sessionChanged()
    await reopened.settled()
    let posts = again.server.sent.filter { $0.route == "POST dive" }.dropFirst(before)
    #expect(posts.count == 1)
    #expect(posts.first?.key == item.idempotencyKey.uuidString.lowercased())
    #expect(posts.first?.body == bytes)
    #expect(reopened.items.isEmpty)
  }

  @Test func whatADiveNamesLandsFirstAndTheDiveCarriesTheServersUuids() async throws {
    let world = try OutboxWorld()
    try await world.load()
    world.offline()
    let model = world.outbox()
    let site = try model.queue(.createDiveSite(DiveSiteCreate(name: "Canyon")))
    let person = try model.queue(.createPerson(PersonCreate(name: "Ana")))
    _ = try model.queue(
      .createDive(Bodies.dive(sites: [site.creates!], people: [person.creates!])))
    await model.settled()

    world.online()
    let mark = world.server.mark
    model.handle(.routeAppeared)
    await model.settled()
    let writes = world.server.writes(since: mark)
    #expect(writes.map(\.route) == ["POST dive-site", "POST person", "POST dive"])
    let created = world.server.created
    let body = writes[2].json
    #expect(body["dive_site_uuids"] as? [String] == [created[0].uuidString.lowercased()])
    let people = body["people"] as? [[String: Any]]
    #expect(people?.first?["person_uuid"] as? String == created[1].uuidString.lowercased())
    #expect(model.items.isEmpty)
  }

  @Test func nothingIsReorderedThatADependencyDoesNotForce() async throws {
    let world = try OutboxWorld()
    try await world.load()
    world.offline()
    let model = world.outbox()
    _ = try model.queue(.createDive(Bodies.dive(1)))
    let site = try model.queue(.createDiveSite(DiveSiteCreate(name: "Canyon")))
    _ = try model.queue(.createDive(Bodies.dive(2, sites: [site.creates!])))
    _ = try model.queue(.createPerson(PersonCreate(name: "Ana")))
    await model.settled()
    world.online()
    let mark = world.server.mark
    model.syncNow()
    await model.settled()
    #expect(
      world.server.writes(since: mark).map(\.route) == [
        "POST dive", "POST dive-site", "POST dive", "POST person",
      ])
  }

  @Test func twoEditsOfOneDiveLandInTheOrderQueued() async throws {
    let world = try OutboxWorld()
    try await world.load()
    let dive = RecordRef.server(UUID())
    world.server.override { request, index in
      request.route.hasPrefix("PATCH ") && index < 2 ? .status(502) : nil
    }
    let model = world.outbox()
    try model.queue(.updateDive(dive, Bodies.notes("first")))
    try model.queue(.updateDive(dive, Bodies.notes("second")))
    await model.settled()
    model.handle(.routeAppeared)
    await model.settled()
    model.handle(.routeAppeared)
    await model.settled()
    #expect(model.items.count == 2)

    model.syncNow()
    await model.settled()
    let patches = world.server.writes.filter { $0.route.hasPrefix("PATCH ") }
    #expect(patches.count == 4)
    #expect(patches.last?.json["notes"] as? String == "second")
    #expect(model.items.isEmpty)
  }

  @Test func aLostReplyIsRetriedUnderTheSameKey() async throws {
    let world = try OutboxWorld()
    try await world.load()
    world.server.override { request, index in
      if request.route == "POST dive", index == 0 { throw URLError(.notConnectedToInternet) }
      return nil
    }
    let model = world.outbox()
    try model.queue(.createDive(Bodies.dive()))
    await model.settled()
    #expect(model.items.first?.lastAnswer == .unreachable)
    model.handle(.routeAppeared)
    await model.settled()
    let posts = world.server.sent.filter { $0.route == "POST dive" }
    #expect(posts.count == 2)
    #expect(Set(posts.map(\.key)).count == 1)
    #expect(model.items.isEmpty)
  }

  @Test func aRefusedSiteHoldsTheDiveNamingItAndNotTheOthers() async throws {
    let world = try OutboxWorld()
    try await world.load()
    world.offline()
    let model = world.outbox()
    let site = try model.queue(.createDiveSite(DiveSiteCreate(name: "")))
    let held = try model.queue(.createDive(Bodies.dive(1, sites: [site.creates!])))
    _ = try model.queue(.createDive(Bodies.dive(2)))
    await model.settled()
    world.server.override { request, _ in
      request.route == "POST dive-site" ? .status(422, "Name is required.") : nil
    }
    model.syncNow()
    await model.settled()

    #expect(model.items.map(\.id) == [site.id, held.id])
    #expect(
      model.items[0].failure
        == OutboxFailure(kind: .refused, status: 422, message: "Name is required."))
    #expect(model.items[0].isEditable)
    #expect(model.items[1].isPending)
    #expect(model.heldBehind(model.items[1])?.id == site.id)
    #expect(world.server.count("POST dive") == 1)
  }

  @Test func aRefusedSessionLeavesEveryItemPending() async throws {
    let world = try OutboxWorld()
    try await world.load()
    world.server.override { request, _ in
      request.route.hasPrefix("POST ") ? .unauthorized : nil
    }
    let model = world.outbox()
    try model.queue(.createDiveSite(DiveSiteCreate(name: "Canyon")))
    try model.queue(.createDive(Bodies.dive()))
    await model.settled()
    #expect(world.session.state == .signingIn(OutboxServer.origin))
    let items = world.storesA.items()
    #expect(items.count == 2)
    #expect(items.allSatisfy { $0.isPending })
  }

  @Test func anUnreadableSuccessIsDoneAndFailsWhatNamedIt() async throws {
    let world = try OutboxWorld()
    try await world.load()
    world.offline()
    let model = world.outbox()
    let site = try model.queue(.createDiveSite(DiveSiteCreate(name: "Canyon")))
    _ = try model.queue(.createDive(Bodies.dive(sites: [site.creates!])))
    await model.settled()
    world.server.override { request, _ in
      request.route == "POST dive-site" ? .json(#"{"surprise":true}"#, status: 201) : nil
    }
    let mark = world.server.mark
    model.syncNow()
    await model.settled()

    #expect(model.items.count == 1)
    #expect(
      model.items.first?.failure
        == OutboxFailure(kind: .unresolvable, message: OutboxText.landedUnreadable))
    #expect(model.notices.map(\.sentence) == [OutboxText.landedUnreadable])
    #expect(world.server.count("POST dive-site", since: mark) == 1)
    #expect(world.server.count("POST dive") == 0)
  }

  @Test func anItemTheServerFailsTwiceIsPassedOverUntilSyncNow() async throws {
    let world = try OutboxWorld()
    try await world.load()
    world.offline()
    let model = world.outbox()
    let stuck = try model.queue(.createDiveSite(DiveSiteCreate(name: "Canyon")))
    await model.settled()
    world.server.override { request, _ in
      request.route == "POST dive-site" ? .status(500) : nil
    }
    let mark = world.server.mark
    model.handle(.routeAppeared)
    await model.settled()
    model.handle(.routeAppeared)
    await model.settled()
    try model.queue(.createDive(Bodies.dive()))
    await model.settled()
    #expect(world.server.count("POST dive-site", since: mark) == 2)
    #expect(world.server.count("POST dive") == 1)
    #expect(model.items.map(\.id) == [stuck.id])
    #expect(model.items.first?.lastAnswer?.sentence == "Last try: the server answered 500")

    model.handle(.routeAppeared)
    await model.settled()
    #expect(world.server.count("POST dive-site", since: mark) == 2)
    model.syncNow()
    await model.settled()
    #expect(world.server.count("POST dive-site", since: mark) == 3)
  }

  @Test func theFlushRunsInsideOneBackgroundAssertion() async throws {
    let world = try OutboxWorld()
    try await world.load()
    world.offline()
    let model = world.outbox()
    try model.queue(.createDiveSite(DiveSiteCreate(name: "Canyon")))
    try model.queue(.createDive(Bodies.dive()))
    await model.settled()
    world.online()
    let before = world.log.all.count
    model.syncNow()
    await model.settled()
    let events = Array(world.log.all.dropFirst(before))
    #expect(events.first == "begin")
    #expect(events.last == "end")
    #expect(events.filter { $0 == "begin" }.count == 1)
  }

  @Test func discardingAFailedCreateReleasesWhatNamedIt() async throws {
    let world = try OutboxWorld()
    try await world.load()
    world.offline()
    let model = world.outbox()
    let site = try model.queue(.createDiveSite(DiveSiteCreate(name: "")))
    let dive = try model.queue(.createDive(Bodies.dive(sites: [site.creates!])))
    let drafts = DraftStore<DiveDraftValues>(
      store: world.session.store, origin: OutboxServer.origin, account: OutboxServer.accountA)
    var edit = DiveDraftValues()
    edit.diveSites = [site.creates!]
    let edited = RecordRef.server(UUID())
    try drafts.save(edit, for: edited)
    await model.settled()
    world.server.override { request, _ in
      request.route == "POST dive-site" ? .status(422) : nil
    }
    model.syncNow()
    await model.settled()

    #expect(model.discardEffects(site.id).released.map(\.id) == [dive.id])
    model.discard(site.id)
    world.online()
    model.syncNow()
    await model.settled()
    let posted = world.server.writes.last { $0.route == "POST dive" }
    #expect(posted?.json["dive_site_uuids"] as? [String] == [])
    #expect(drafts.load(edited)?.diveSites == [])
  }

  @Test func aDiscardedDraftsLogBecomesAPlainDive() async throws {
    let world = try OutboxWorld()
    try await world.load()
    world.server.override { request, _ in
      request.route == "POST dive-draft" ? .status(500) : nil
    }
    let model = world.outbox()
    let draft = try model.beginDraft(Bodies.draft("a"))
    model.leaveDraft()
    await model.settled()
    try model.logDraft(draft, Bodies.dive())
    let create = model.items.first { $0.creates == draft }!
    model.discard(create.id)
    world.online()
    model.syncNow()
    await model.settled()
    #expect(world.server.count("POST dive") == 1)
    #expect(model.items.isEmpty)
  }

  @Test func anItemOfAnUnknownShapeIsListedKeptAndNeverSent() async throws {
    let world = try OutboxWorld()
    try await world.load()
    let folder = world.session.store.directory(
      for: OutboxServer.origin, account: OutboxServer.accountA
    ).appendingPathComponent("Outbox/items", isDirectory: true)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let strange = folder.appendingPathComponent("0000-strange.json")
    let bytes = Data(#"{"kind":"teleport_dive","body":{}}"#.utf8)
    try bytes.write(to: strange)

    let model = world.outbox()
    #expect(model.unreadable == ["0000-strange.json"])
    try model.queue(.createDive(Bodies.dive()))
    await model.settled()
    #expect(try Data(contentsOf: strange) == bytes)
    #expect(world.server.writes.map(\.route) == ["POST dive"])
    #expect(
      OutboxStore.summary(store: world.session.store, origin: OutboxServer.origin).unreadable == 1)
    model.discardUnreadable("0000-strange.json")
    #expect(!FileManager.default.fileExists(atPath: strange.path))
  }

  @Test func anEditReQueuesARefusedCreateUnderItsKey() async throws {
    let world = try OutboxWorld()
    try await world.load()
    world.server.override { request, index in
      request.route == "POST dive-site" && index == 0 ? .status(422) : nil
    }
    let model = world.outbox()
    let site = try model.queue(.createDiveSite(DiveSiteCreate(name: "")))
    await model.settled()
    #expect(model.items.first?.isEditable == true)
    try model.edit(site.id, .createDiveSite(DiveSiteCreate(name: "Canyon")))
    await model.settled()
    let posts = world.server.sent.filter { $0.route == "POST dive-site" }
    #expect(posts.count == 2)
    #expect(posts[1].json["name"] as? String == "Canyon")
    #expect(posts[1].key == posts[0].key)
    #expect(model.items.isEmpty)
  }

  @Test func anAttemptedCreateCannotBeEdited() async throws {
    let world = try OutboxWorld()
    try await world.load()
    world.offline()
    let model = world.outbox()
    let site = try model.queue(.createDiveSite(DiveSiteCreate(name: "Canyon")))
    await model.settled()
    #expect(model.items.first?.attempted == true)
    #expect(model.items.first?.isEditable == false)
    #expect(throws: OutboxModel.OutboxError.notEditable) {
      try model.edit(site.id, .createDiveSite(DiveSiteCreate(name: "Other")))
    }
  }
}
