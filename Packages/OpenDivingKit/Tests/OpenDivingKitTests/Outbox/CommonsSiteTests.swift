import Foundation
import Testing

@testable import OpenDivingKit

/// A Commons record on the phone: saved from the Sites tab through the queue, named on a dive
/// or a draft it was never saved from, and edited in the diver's own members alone.
@MainActor
struct CommonsSiteTests {
  private static let credit =
    "[Data © OpenStreetMap contributors, ODbL 1.0.](https://osm.org/copyright)"
  private static let uuid = UUID(uuidString: "01a14b2e-0c3d-7a10-9f00-4b2b3c4d5e6f")!

  private func record(saved: Bool = false) -> DiveSiteLookupItem {
    DiveSiteLookupItem(
      ref: .server(Self.uuid), name: "Quarry", owner: DiveSiteOwner.commons, saved: saved,
      attribution: Self.credit)
  }

  private func read(_ changes: [String: Any] = [:]) throws -> DiveSiteRead {
    var object =
      try JSONSerialization.jsonObject(with: Data(KitFixture.text("dive-site").utf8))
      as! [String: Any]
    object["owner"] = DiveSiteOwner.commons
    object["attribution"] = Self.credit
    object.merge(changes) { _, new in new }
    return try APICoding.decoder().decode(
      DiveSiteRead.self, from: JSONSerialization.data(withJSONObject: object))
  }

  // MARK: - Saving

  @Test func savingIsAPutWithNoBodyAndTheRowIsListedBeforeAndAfterItLands() async throws {
    let world = try OutboxWorld()
    let outbox = world.outbox()
    try await world.load(outbox)
    let lookups = LookupsModel(session: world.session)
    world.offline()
    try outbox.queue(.saveDiveSite(record()))
    await outbox.settled()
    #expect(lookups.diveSites.map(\.ref) == [.server(Self.uuid)])

    let mark = world.server.mark
    world.online()
    outbox.syncNow()
    await outbox.settled()
    let wire = APIClient.wire(Self.uuid)
    let write = try #require(world.server.writes(since: mark).first)
    #expect(write.route == "PUT dive-site/\(wire)/saved")
    #expect(write.body == nil)
    #expect(write.key == nil)
    #expect(outbox.items.isEmpty)
    #expect(world.server.count("GET dive-sites/lookup", since: mark) == 1)
    // The refresh answered an empty list here; the row the landing wrote was overwritten by it,
    // so what stands is the server's answer.
    #expect(world.cacheA.lookup(.diveSites, of: DiveSiteLookupItem.self)?.value == [])
  }

  @Test func aSaveLandingKeepsItsRowWhenTheRefreshFails() async throws {
    let world = try OutboxWorld()
    let outbox = world.outbox()
    try await world.load(outbox)
    world.server.override { request, _ in
      if request.route == "GET dive-sites/lookup" { throw URLError(.notConnectedToInternet) }
      return nil
    }
    try outbox.queue(.saveDiveSite(record()))
    await outbox.settled()
    let rows = world.cacheA.lookup(.diveSites, of: DiveSiteLookupItem.self)?.value
    #expect(rows?.map(\.ref) == [.server(Self.uuid)])
    #expect(rows?.first?.saved == true)
    #expect(rows?.first?.isCommons == true)
  }

  @Test func aQueuedSaveSurvivesARelaunchAndIsOnlyDiscarded() throws {
    let operation = OutboxOperation.saveDiveSite(record())
    let encoded = try APICoding.encoder().encode(operation)
    #expect(try APICoding.decoder().decode(OutboxOperation.self, from: encoded) == operation)
    #expect(operation.target == .server(Self.uuid))
    #expect(operation.kind == .diveSite)

    let item = OutboxItem(operation: operation, sequence: 0, marked: false)
    #expect(!item.isEditable)
    #expect(item.isDiscardable)
    #expect(PendingText.title(of: item) == "Save to your sites: Quarry")
    #expect(PendingText.waiting([item]) == "A site waiting to sync")
  }

  // MARK: - Naming

  @Test func aPickedRecordIsNamedByTheFormAndByAQueuedEditOfADive() async throws {
    let world = try FormWorld()
    try await world.loaded()
    let page = PaginatedListResponse(
      data: [record()], totalCount: 1, hasMore: false, page: 1, itemsPerPage: 25)
    let body = String(decoding: try APICoding.encoder().encode(page), as: UTF8.self)
    world.server.override { request, _ in
      request.route == "GET dive-sites/lookup" && request.url?.query?.contains("search") == true
        ? .json(body) : nil
    }
    let model = await world.form(.create)
    let found = await model.searchServer(.diveSites, matching: "qua")
    #expect(found.map(\.isCommons) == [true])
    #expect(found.first?.attribution == Self.credit)
    model.addSite(.server(Self.uuid))
    await model.settled()

    // A later form, with no search behind it, still has the name.
    let again = await world.form(.create)
    #expect(again.row(.server(Self.uuid), .diveSites).title == "Quarry")
    #expect(again.rows(.diveSites, matching: "").isEmpty)

    let stores = try #require(AccountStores.current(world.session))
    let tables = LookupTables(cache: stores.cache, items: [])
    let dive = try KitFixture.decode(DiveReadWithMixtures.self, "dive-detail")
    var update = DiveUpdate()
    update.diveSites = [.server(Self.uuid)]
    let edited = dive.applying([update], tables: tables)
    #expect(edited?.diveSites.map(\.name) == ["Quarry"])
  }

  @Test func aRecordTakenFromTheSiteFormIsKeptWhenAdded() async throws {
    let world = try FormWorld()
    try await world.loaded()
    let model = await world.form(.create)
    model.take(record())
    #expect(model.row(.server(Self.uuid), .diveSites).isCommons)
    model.addSite(.server(Self.uuid))
    #expect(model.lookups.namedSites.map(\.name) == ["Quarry"])
    #expect(model.values.diveSites == [.server(Self.uuid)])
  }

  @Test func aSavedSiteIsNotKeptApart() async throws {
    let world = try FormWorld()
    try await world.loaded()
    let model = await world.form(.create)
    model.take(record(saved: true))
    model.addSite(.server(Self.uuid))
    #expect(model.lookups.namedSites.isEmpty)
  }

  @Test func aDraftsSiteThePhoneCannotNameIsFetchedByUuid() async throws {
    let world = try OutboxWorld()
    let outbox = world.outbox()
    try await world.load(outbox)
    let page = PaginatedListResponse(
      data: [record()], totalCount: 1, hasMore: false, page: 1, itemsPerPage: 50)
    let body = String(decoding: try APICoding.encoder().encode(page), as: UTF8.self)
    let wire = APIClient.wire(Self.uuid)
    world.server.override { request, _ in
      request.route == "GET dive-sites/lookup" && request.url?.query?.contains(wire) == true
        ? .json(body) : nil
    }
    var values = DiveDraftValues()
    values.diveSites = [.server(Self.uuid)]
    world.offline()
    _ = try outbox.beginDraft(DiveDraftWrite(gearSet: nil, values: values))
    world.server.override { request, _ in
      if request.route == "GET dive-sites/lookup", request.url?.query?.contains(wire) == true {
        return .json(body)
      }
      if !request.route.hasPrefix("GET ") { throw URLError(.notConnectedToInternet) }
      return nil
    }
    let lookups = LookupsModel(session: world.session)
    await lookups.refresh()
    #expect(lookups.namedSites.map(\.name) == ["Quarry"])
    let rows = DiveDraftRowContent.rows(
      outbox.drafts, sites: lookups.diveSites + lookups.namedSites, timeZone: .gmt)
    #expect(rows.first?.detail.hasPrefix("Quarry · ") == true)
  }

  // MARK: - Editing

  @Test func anEditOfACommonsRecordSendsTheNotesAndTheTagsAlone() throws {
    let before = DiveSiteFormValues(editing: try read(["saved": true]))
    var after = before
    after.name = "Elsewhere"
    after.latitude = "28.5"
    after.longitude = "34.5"
    after.depthTo = 30
    after.notes = "Gate code 1234"
    after.tags = ["wreck"]
    var expected = DiveSiteUpdate()
    expected.notes = "Gate code 1234"
    expected.tags = ["wreck"]
    #expect(try after.diff(from: before) == expected)

    var shared = before
    shared.name = "Elsewhere"
    #expect(try shared.update(of: .server(Self.uuid), from: before) == nil)
  }

  @Test func aCommonsRecordIsHeldOnlyToTheRulesOfWhatTheDiverWrites() throws {
    var values = DiveSiteFormValues(editing: try read(["saved": true, "name": "  "]))
    values.depthFrom = -1
    #expect(values.issues.isEmpty)
    values.notes = String(repeating: "x", count: DiveFormBounds.notesMax + 1)
    #expect(values.issues.map(\.field) == ["notes"])
  }

  @Test func aDiversOwnSiteStillEditsEverything() throws {
    let before = DiveSiteFormValues(editing: try read(["owner": DiveSiteOwner.account]))
    var after = before
    after.name = "Elsewhere"
    #expect(try after.diff(from: before).name == "Elsewhere")
  }

  @Test func onlyAnUnsavedRecordIsRefusedAnEditForm() throws {
    #expect(try read(["saved": false]).isUnsavedCommons)
    #expect(try !read(["saved": true]).isUnsavedCommons)
    #expect(try !read(["owner": DiveSiteOwner.account, "saved": true]).isUnsavedCommons)
  }

  @Test func aSavedRecordsFormQueuesAPatchOfTheNotesAndItsDeleteTheDelete() async throws {
    let world = try OutboxWorld()
    let outbox = world.outbox()
    try await world.load(outbox)
    world.offline()
    let site = try read(["saved": true])
    let model = RecordSheetModel(
      outbox: outbox, editing: .server(site.uuid), read: DiveSiteFormValues(editing: site))
    model.values.notes = "Mine"
    #expect(model.save() == .server(site.uuid))
    #expect(model.canDelete)
    guard case .updateDiveSite(_, let update) = outbox.items.first?.operation else {
      Issue.record("Nothing queued")
      return
    }
    #expect(update.notes == "Mine")
    #expect(update.name == nil)
  }

  @Test func aFormSavesARecordToTheListThroughTheQueue() async throws {
    let world = try OutboxWorld()
    let outbox = world.outbox()
    try await world.load(outbox)
    world.offline()
    let model = RecordSheetModel(outbox: outbox, values: DiveSiteFormValues())
    #expect(model.saveToList(record()))
    #expect(outbox.items.map(\.operation) == [.saveDiveSite(record())])
  }

  // MARK: - Words

  @Test func aCommonsSiteIsMarkedAndItsSharedMembersListed() throws {
    let site = try read([
      "saved": true, "water_type": "fresh", "depth_to": 30, "altitude": 372,
      "entry_types": ["shore"], "other_names": ["Old Quarry"],
      "external_ids": [["registry": "openstreetmap", "identifier": "node/1"]],
    ])
    #expect(DiveSiteSummary.card(site, units: .metric).chips.map(\.text) == ["Commons"])
    #expect(DiveSiteSummary.hero(site, units: .metric).chips.map(\.text) == ["Commons"])
    #expect(
      DiveSiteSummary.chips(site) == [
        Chip(text: "Commons", accessibilityLabel: "OpenDiving Commons site", kind: .site(.commons))
      ])
    #expect(
      DiveSiteSummary.sharedMembers(site, units: .metric).map(\.label) == [
        "Name", "Also known as", "Location", "Depth", "Water type", "Altitude", "Entry types",
        "OpenStreetMap",
      ])
    let own = try read(["owner": DiveSiteOwner.account])
    #expect(DiveSiteSummary.card(own, units: .metric).chips.map(\.text) == ["Private"])
    #expect(DiveSiteSummary.hero(own, units: .metric).chips.isEmpty)
  }
}
