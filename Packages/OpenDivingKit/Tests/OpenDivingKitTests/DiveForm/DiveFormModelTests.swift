import Foundation
import Synchronization
import Testing

@testable import OpenDivingKit

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// A route the test switches on and off: what the form reads to decide whether to ask the
/// server for a suggestion or a search.
final class SwitchedRoute: Connectivity {
  private let available = Mutex(true)

  var isRouteAvailable: Bool {
    get { available.withLock { $0 } }
    set { available.withLock { $0 = newValue } }
  }

  func moments() -> AsyncStream<ConnectivityMoment> {
    AsyncStream<ConnectivityMoment>.makeStream().stream
  }
}

/// A phone over an ``OutboxServer`` whose route the test controls, and the forms it opens.
@MainActor
struct FormWorld {
  let server: OutboxServer
  let route = SwitchedRoute()
  let session: Session
  static let now = Date(timeIntervalSince1970: 1_792_400_000)
  static let zone = TimeZone(secondsFromGMT: 3 * 3600)!
  static let dive = UUID(uuidString: "9c890a72-f1cb-5eef-ae82-3ed803b61f17")!

  init() throws {
    server = try OutboxServer()
    session = Session(
      transport: server,
      secrets: InMemorySecretStore([OutboxServer.origin.description: "refresh"]),
      activeOrigin: InMemoryActiveOriginStore(OutboxServer.origin),
      background: NoBackgroundExecution(), connectivity: route,
      applicationSupport: FileManager.default.temporaryDirectory.appendingPathComponent(
        "DiveFormTests-\(UUID().uuidString)", isDirectory: true),
      userAgent: ClientHarness.userAgent, accessToken: "live")
  }

  /// No route, and every write fails as if there were none.
  func offline() {
    route.isRouteAvailable = false
    server.override { request, _ in
      guard request.route.hasPrefix("GET ") else { throw URLError(.notConnectedToInternet) }
      return nil
    }
  }

  func online() {
    route.isRouteAvailable = true
    server.override { _, _ in nil }
  }

  /// The account loaded, the Dives tab's first page shown and its first dive opened, as the
  /// phone would have before a trip.
  func loaded(showingTheLog: Bool = true) async throws {
    try await session.loadAccount()
    guard showingTheLog else { return }
    let list = PagedList<DiveListItem>(session: session, cache: .dives) { client, page, size in
      try await client.dives(page: page, itemsPerPage: size)
    }
    await list.load()
    await DiveDetailModel(session: session, diveUUID: Self.dive).load()
  }

  func form(_ mode: DiveFormModel.Mode) async -> DiveFormModel {
    let model = DiveFormModel(
      session: session, mode: mode, now: Self.now, timeZone: Self.zone,
      quietInterval: .milliseconds(50))
    await model.start()
    await model.settled()
    return model
  }
}

@MainActor
struct DiveFormModelTests {
  // MARK: - A new dive

  @Test func aFormOpenedAndLeftLeavesNothingBehind() async throws {
    let world = try FormWorld()
    try await world.loaded()
    let mark = world.server.mark
    let model = await world.form(.create)
    model.leave()
    await model.settled()
    #expect(model.outbox.items.isEmpty)
    #expect(model.draft == nil)
    #expect(world.server.writes(since: mark).isEmpty)
  }

  @Test func aNewDiveStartsNowNumberedAboveTheNewestAndCarriesTheLastDive() async throws {
    let world = try FormWorld()
    try await world.loaded()
    world.offline()
    let model = await world.form(.create)
    #expect(model.values.diveNumber == 533)
    #expect(model.values.startTime == DiveStart.now(FormWorld.now, in: FormWorld.zone))
    // The last dive's tank carries, its pressures blanked.
    #expect(model.values.tanks.count == 1)
    #expect(model.values.tanks.first?.oxygen == 31)
    #expect(model.values.tanks.first?.startPressure == nil)
    #expect(model.title == "Log New Dive")
    #expect(model.submitLabel == "Log dive")
  }

  @Test func offlineNothingIsAskedOfTheServer() async throws {
    let world = try FormWorld()
    try await world.loaded()
    world.offline()
    let mark = world.server.mark
    let model = await world.form(.create)
    #expect(await model.searchServer(.people, matching: "Sam").isEmpty)
    #expect(await model.searchSpecies("goby").isEmpty)
    let asked = world.server.sent.dropFirst(mark).map(\.route)
    #expect(!asked.contains { $0.hasPrefix("GET dives/next-number") })
    #expect(!asked.contains { $0.contains("/lookup") || $0.contains("species/suggest") })
  }

  @Test func onlineTheNumberAndTheSearchesAskTheServer() async throws {
    let world = try FormWorld()
    try await world.loaded()
    world.server.override { request, _ in
      request.route == "GET dives/next-number"
        ? .json(#"{"dive_number":540,"is_taken":true}"#) : nil
    }
    let model = await world.form(.create)
    #expect(model.values.diveNumber == 540)
    #expect(model.numberNotice?.hasPrefix("Another dive is already numbered #540.") == true)
    _ = await model.searchServer(.people, matching: "Sam")
    _ = await model.searchSpecies("goby")
    let routes = world.server.routes
    #expect(routes.contains("GET people/lookup"))
    #expect(routes.contains("GET user/species/suggest"))
    let search = world.server.sent.last { $0.route == "GET people/lookup" }
    #expect(search != nil)
  }

  @Test func theFirstChangeIsADraftAndLogDiveQueuesOneDive() async throws {
    let world = try FormWorld()
    try await world.loaded()
    world.offline()
    let model = await world.form(.create)
    model.change { $0.submergedTime = "48" }
    model.change { $0.maxDepth = model.metric(fromEntry: "18,3", .depth) }
    await model.settled()
    let draft = try #require(model.draft)
    #expect(model.outbox.drafts.map(\.ref) == [draft])
    #expect(model.outbox.items.map(\.operation.kind) == [.diveDraft])

    #expect(model.submit())
    #expect(model.isDone)
    #expect(model.outbox.drafts.isEmpty)
    let create = try #require(model.outbox.items.compactMap(\.operation.diveCreate).first)
    #expect(create.submergedTime == 48 * 60)
    #expect(create.maxDepth == 18.3)
    #expect(model.outbox.queuedDiveCreates == 1)

    // The draft's create waited for a route, so the log withdrew it: one dive and no draft.
    world.online()
    let mark = world.server.mark
    model.outbox.syncNow()
    await model.outbox.settled()
    #expect(world.server.writes(since: mark).map(\.route) == ["POST dive"])
    #expect(model.outbox.items.isEmpty)
  }

  @Test func logDiveShowsTheWebsSentencesAndQueuesNothing() async throws {
    let world = try FormWorld()
    try await world.loaded()
    world.offline()
    let model = await world.form(.create)
    #expect(model.message("submerged_time") == nil)
    #expect(!model.submit())
    #expect(model.message("submerged_time") == "Dive time is required")
    #expect(model.outbox.items.isEmpty)
    model.change { $0.submergedTime = "45:75" }
    #expect(
      model.message("submerged_time") == "Dive time must be minutes or MM:SS, e.g. 45 or 67:30")
  }

  @Test func feetAreTypedAndMetresAreKept() async throws {
    let world = try FormWorld()
    try await world.loaded()
    let model = await world.form(.create)
    model.toggleEntryUnits(.depth)
    #expect(model.entryUnits(.depth) == .imperial)
    #expect(model.label("Maximum depth", .depth) == "Maximum depth (ft)")
    #expect(model.metric(fromEntry: "60", .depth) == 18.29)
    #expect(model.placeholder(30.52, .depth) == "e.g. 100")
    // The toggle is the phone's, and kept.
    let again = await world.form(.create)
    #expect(again.entryUnits(.depth) == .imperial)
  }

  @Test func theAccountsHiddenFieldsAreHiddenOnANewDive() async throws {
    let world = try FormWorld()
    try await world.loaded()
    let model = await world.form(.create)
    #expect(!model.shows(.course))
    #expect(!model.shows(.sightings))
    #expect(!model.sections.contains(.training))
    #expect(!model.sections.contains(.marineLife))
    #expect(model.sections.contains(.diveInfo))
  }

  // MARK: - Drafts

  @Test func aDraftReopensAsItWasLeftAndIsDiscarded() async throws {
    let world = try FormWorld()
    try await world.loaded()
    world.offline()
    let first = await world.form(.create)
    first.change { $0.notes = "At the water's edge" }
    first.leave()
    await first.settled()
    let ref = try #require(first.draft)

    let reopened = await world.form(.draft(ref))
    #expect(reopened.phase == .ready)
    #expect(reopened.values.notes == "At the water's edge")
    #expect(reopened.draftRows.map(\.ref) == [ref])

    // Its create waited for a route, so the discard withdraws it and nothing is sent.
    reopened.discardDraft()
    #expect(reopened.isDone)
    #expect(reopened.outbox.drafts.isEmpty)
    #expect(reopened.outbox.items.isEmpty)
  }

  @Test func aDraftKeepsTheSetItNamesWhenThePhoneHasNotFetchedIt() async throws {
    let world = try FormWorld()
    try await world.loaded()
    world.offline()
    let set = RecordRef.server(UUID())
    let outbox = OutboxModel(session: world.session)
    var values = DiveDraftValues()
    values.notes = "Packed on the web"
    let ref = try outbox.beginDraft(DiveDraftWrite(gearSet: set, values: values))

    let model = await world.form(.draft(ref))
    #expect(model.checklist == nil)
    #expect(model.gearSet == set)
    model.change { $0.notes = "Finished on the phone" }
    await model.settled()
    #expect(model.outbox.drafts.first?.write.gearSet == set)

    // The set arrives with a refresh after the edit, and opens as the checklist.
    let mask = GearItemInfo(ref: .server(UUID()), name: "Mask")
    let stores = try #require(AccountStores.current(world.session))
    stores.cache.writeLookup(
      [GearSetRow(ref: set, name: "Reef kit", items: [mask])], table: .gearSets)
    OutboxHub.hub(for: stores.directory).changed()
    #expect(model.checklist?.name == "Reef kit")
  }

  @Test func returnOnAKnownNameAddsThatPersonRatherThanASecond() async throws {
    let world = try FormWorld()
    try await world.loaded()
    world.offline()
    let model = await world.form(.create)
    #expect(model.addPerson(named: "ana diaz"))
    let ana = RecordRef.server(UUID(uuidString: "01a0e2ed-1be1-7142-996d-0639721e344d")!)
    #expect(model.values.people.map(\.person) == [ana])
    #expect(model.addPerson(named: "Ana Diaz"))
    #expect(model.values.people.count == 1)
    #expect(model.outbox.items.allSatisfy { $0.operation.kind != .person })
  }

  @Test func aDraftNoLongerHereSaysSo() async throws {
    let world = try FormWorld()
    try await world.loaded()
    let model = await world.form(.draft(.server(UUID())))
    #expect(model.phase == .unavailable(DiveFormModel.draftGone))
  }

  @Test func theTicksAreTheDraftsGear() async throws {
    let world = try FormWorld()
    try await world.loaded()
    world.offline()
    let model = await world.form(.create)
    let mask = GearItemInfo(ref: .server(UUID()), name: "Mask")
    let fins = GearItemInfo(ref: .server(UUID()), name: "Fins", isArchived: true)
    let set = GearSetRow(ref: .server(UUID()), name: "Reef kit", weight: 6, items: [mask, fins])
    #expect(model.loadingSetReplacesGear == false)
    #expect(DiveFormModel.setLabel(set) == "Reef kit (2)")

    model.loadSet(set)
    #expect(model.isChecklistOpen)
    #expect(model.values.gearItems.isEmpty)
    #expect(model.values.weight == 6)
    model.toggleChecklistItem(mask.ref)
    #expect(model.values.gearItems == [mask.ref])
    await model.settled()
    let write = try #require(model.outbox.drafts.first?.write)
    #expect(write.gearSet == set.ref)
    #expect(write.values.gearItems == [mask.ref])

    model.tickAll()
    model.closeChecklist()
    #expect(model.values.gearItems == [mask.ref, fins.ref])
    #expect(model.loadingSetReplacesGear)
    #expect(
      model.replaceSentence(set)
        == "Loading \"Reef kit\" replaces the 2 items currently on this dive.")
  }

  // MARK: - Editing

  @Test func anEditSendsOnlyWhatChanged() async throws {
    let world = try FormWorld()
    try await world.loaded()
    world.offline()
    let model = await world.form(.edit(FormWorld.dive))
    #expect(model.phase == .ready)
    #expect(model.title == "Edit Dive #532")
    #expect(model.submitLabel == "Save changes")
    model.change { $0.rating = 4 }
    model.change { $0.notes = "Turtle at the wall" }
    #expect(model.submit())
    var expected = DiveUpdate()
    expected.rating = .value(4)
    expected.notes = "Turtle at the wall"
    #expect(model.outbox.items.map(\.operation) == [.updateDive(.server(FormWorld.dive), expected)])
    #expect(DraftStore<DiveEditDraft>(session: world.session)?.load(.server(FormWorld.dive)) == nil)
  }

  @Test func anEditLeftUnsavedIsThereNextTime() async throws {
    let world = try FormWorld()
    try await world.loaded()
    let model = await world.form(.edit(FormWorld.dive))
    model.change { $0.notes = "Half written" }
    model.leave()
    await model.settled()

    let again = await world.form(.edit(FormWorld.dive))
    #expect(again.hasEditDraft)
    #expect(again.values.notes == "Half written")
    again.discardEdit()
    #expect(again.values.notes == "")
    #expect(!again.hasEditDraft)
  }

  @Test func aRefusedEditReopensWithTheServersSentenceAndGoesAgain() async throws {
    let world = try FormWorld()
    try await world.loaded()
    world.server.override { request, _ in
      request.route.hasPrefix("PATCH dive/") ? .status(422, "Notes are too long.") : nil
    }
    let edit = await world.form(.edit(FormWorld.dive))
    edit.change { $0.notes = "Changed offline" }
    #expect(edit.submit())
    await edit.outbox.settled()
    let item = try #require(edit.outbox.items.first)
    #expect(item.isFailed)

    let failed = await world.form(.failed(item.id))
    #expect(failed.serverSentence == "Notes are too long.")
    #expect(failed.values.notes == "Changed offline")
    #expect(failed.submitLabel == "Save changes")
    world.server.override { _, _ in nil }
    failed.change { $0.notes = "Changed again" }
    #expect(failed.submit())
    await failed.outbox.settled()
    #expect(failed.outbox.items.isEmpty)
    let patch = try #require(world.server.writes.last { $0.route.hasPrefix("PATCH dive/") })
    #expect(patch.json["notes"] as? String == "Changed again")
  }

  // MARK: - Pickers

  @Test func aPersonCreatedOnEnterIsABuddyAndNamedByTheServerOnceLanded() async throws {
    let world = try FormWorld()
    try await world.loaded()
    world.offline()
    let model = await world.form(.create)
    #expect(model.addPerson(named: "  Sam  "))
    let person = try #require(model.values.people.first)
    #expect(person.person.isLocal)
    #expect(person.role == "buddy")
    #expect(model.row(person.person, .people).title == "Sam")
    #expect(model.row(person.person, .people).isPending)
    #expect(!model.addPerson(named: "   "))

    world.online()
    model.outbox.syncNow()
    await model.outbox.settled()
    #expect(model.values.people.first?.person.isLocal == false)
  }

  @Test func theCylinderPickerSaysWhyItIsEmpty() async throws {
    let world = try FormWorld()
    try await world.loaded()
    let model = await world.form(.create)
    #expect(model.emptySentence(.cylinder, matching: "") == "No cylinders in your gear yet.")
    #expect(model.emptySentence(.trip, matching: "x") == "No trips yet.")
    #expect(model.emptySentence(.contact, matching: "") == "No contacts yet.")
    #expect(
      model.emptySentence(.people, matching: "Zed")
        == "Nobody matches. Press Enter to add a person of that name.")
  }

  // MARK: - Signed out

  @Test func signedOutTheFormIsTheAccountsUnitsAndQueuesWithNoRequest() async throws {
    let world = try FormWorld()
    world.server.override { request, _ in
      guard request.route == "GET user" else { return nil }
      let user = try KitFixture.text("user").replacingOccurrences(
        of: #""units": "metric""#, with: #""units": "imperial""#)
      return .json(user)
    }
    try await world.loaded(showingTheLog: false)
    try await world.session.signOut()
    #expect(world.session.units == .metric)
    let mark = world.server.mark

    let model = await world.form(.create)
    #expect(model.units == .imperial)
    #expect(model.label("Maximum depth", .depth) == "Maximum depth (ft)")
    #expect(!model.shows(.course))
    #expect(!model.isOnline)
    model.change { $0.submergedTime = "40" }
    #expect(model.submit() == false)  // no number is known offline with nothing shown
    model.change { $0.diveNumber = 1 }
    #expect(model.submit())
    #expect(model.outbox.items.first?.writtenBeforeAccountKnown == false)
    await model.settled()
    #expect(world.server.mark == mark)
  }

  // MARK: - The tank hint

  @Test func aSingleTankHintsAtItsEquivalentDepth() async throws {
    let world = try FormWorld()
    try await world.loaded()
    let model = await world.form(.create)
    model.change { values in
      values.tanks = [TankValues(volume: 12, oxygen: 32, helium: 0)]
      values.maxDepth = 30
    }
    #expect(model.tankHint(0) == "EAN32 · MOD 33.75 m @ ppO₂ 1.4 · EAD 24.4 m at 30 m")
    model.addTank()
    #expect(model.tankHint(0) == "EAN32 · MOD 33.75 m @ ppO₂ 1.4")
    #expect(model.tankHint(1) == "Air · MOD 56.66 m @ ppO₂ 1.4")
  }
}
