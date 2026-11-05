import Foundation
import Testing

@testable import OpenDivingKit

/// Edits and deletes of the records a tab lists, through the queue.
@MainActor
struct RecordEditQueueTests {
  private static let tripUUID = UUID(uuidString: "01a0a57a-92c3-73d0-8f2c-e200878f9878")!
  private static let dive = UUID(uuidString: "01a0a57a-92c3-73d0-8f2c-e200878f9871")!
  private var trip: RecordRef { .server(Self.tripUUID) }

  private func values() throws -> TripFormValues {
    TripFormValues(editing: try KitFixture.decode(TripRead.self, "trip"))
  }

  private func form(_ outbox: OutboxModel, failedItem: UUID? = nil) throws
    -> RecordSheetModel<TripFormValues>
  {
    RecordSheetModel(outbox: outbox, editing: trip, read: try values(), failedItem: failedItem)
  }

  private func tripsPage() throws -> String {
    #"{"data":[\#(try KitFixture.text("trip"))],"total_count":1,"has_more":false,"page":1,"#
      + #""items_per_page":100}"#
  }

  // MARK: - Editing

  @Test func anEditIsSentAsAPatchOfWhatChanged() async throws {
    let world = try OutboxWorld()
    try await world.load()
    let outbox = world.outbox()
    let form = try form(outbox)
    form.values.notes = "Windy"

    #expect(form.save() == trip)
    await outbox.settled()
    let write = try #require(world.server.writes.last)
    #expect(write.route == "PATCH trip/\(Self.tripUUID.uuidString.lowercased())")
    #expect(write.json as NSDictionary == ["notes": "Windy"])
    #expect(outbox.items.isEmpty)
  }

  @Test func anEditWithNothingChangedQueuesNothingAndStillCloses() async throws {
    let world = try OutboxWorld()
    try await world.load()
    world.offline()
    let outbox = world.outbox()
    #expect(try form(outbox).save() == trip)
    #expect(outbox.items.isEmpty)
  }

  @Test func aFormReopensOverItsQueuedEditAndTakingItBackIsSent() async throws {
    let world = try OutboxWorld()
    try await world.load()
    world.offline()
    let outbox = world.outbox()
    let first = try form(outbox)
    let original = first.values.name
    first.values.name = "Dahab again"
    _ = first.save()

    let second = try form(outbox)
    #expect(second.values.name == "Dahab again")
    second.values.name = original
    _ = second.save()
    #expect(outbox.items.map(\.operation).last == .updateTrip(trip, TripUpdate(name: original)))
    await outbox.settled()
  }

  @Test func aRefusedEditReopensWithItsChangesAndIsSentAgainUnderItsItem() async throws {
    let world = try OutboxWorld()
    try await world.load()
    world.server.override { request, index in
      request.route.hasPrefix("PATCH ") && index == 0 ? .status(422, "Name taken") : nil
    }
    let outbox = world.outbox()
    let first = try form(outbox)
    first.values.name = "Taken"
    _ = first.save()
    await outbox.settled()
    let refused = try #require(outbox.items.first)
    #expect(refused.isFailed && refused.isEditable)

    let form = try form(outbox, failedItem: refused.id)
    #expect(form.failure == "Name taken")
    #expect(form.values.name == "Taken")
    #expect(!form.canDelete)
    form.values.name = "Free"
    #expect(form.save() == trip)
    await outbox.settled()
    #expect(outbox.items.isEmpty)
    #expect(world.server.writes.last?.json as NSDictionary? == ["name": "Free"])
  }

  @Test func aRefusedEditTakenBackIsDiscarded() async throws {
    let world = try OutboxWorld()
    try await world.load()
    world.server.override { request, _ in
      request.route.hasPrefix("PATCH ") ? .status(422, "Name taken") : nil
    }
    let outbox = world.outbox()
    let first = try form(outbox)
    let original = first.values.name
    first.values.name = "Taken"
    _ = first.save()
    await outbox.settled()

    let form = try form(outbox, failedItem: try #require(outbox.items.first).id)
    form.values.name = original
    #expect(form.save() == trip)
    #expect(outbox.items.isEmpty)
  }

  @Test func anEditOfARecordGoneFromTheServerOffersDiscardAlone() async throws {
    let world = try OutboxWorld()
    try await world.load()
    world.server.override { request, _ in
      request.route.hasPrefix("PATCH ") ? .status(404, "Not found") : nil
    }
    let outbox = world.outbox()
    try outbox.queue(.updateTrip(trip, TripUpdate(name: "Gone")))
    try outbox.queue(
      .updateDiveSite(
        .server(UUID()),
        {
          var u = DiveSiteUpdate()
          u.name = "Gone"
          return u
        }()))
    await outbox.settled()
    #expect(outbox.items.count == 2)
    #expect(outbox.items.allSatisfy { !$0.isEditable && $0.isDiscardable })
  }

  @Test func theNewWritesSurviveARelaunch() async throws {
    let world = try OutboxWorld()
    try await world.load()
    world.offline()
    let outbox = world.outbox()
    var site = DiveSiteUpdate()
    site.latitude = .null
    site.longitude = .null
    site.name = "Lighthouse"
    let siteRef = RecordRef.server(UUID())
    let queued: [OutboxOperation] = [
      .updateTrip(trip, TripUpdate(notes: "Windy", parts: [])), .updateDiveSite(siteRef, site),
      .deleteDive(.server(Self.dive)),
    ]
    for operation in queued { try outbox.queue(operation) }
    await outbox.settled()
    #expect(try world.relaunched().outbox().items.map(\.operation) == queued)
  }

  // MARK: - Deleting

  @Test func eachDeleteIsSentToItsRecordsRoute() async throws {
    let world = try OutboxWorld()
    try await world.load()
    let outbox = world.outbox()
    let (dive, trip, site) = (UUID(), UUID(), UUID())
    try outbox.queue(.deleteDive(.server(dive)))
    try outbox.queue(.deleteTrip(.server(trip)))
    try outbox.queue(.deleteDiveSite(.server(site)))
    await outbox.settled()
    #expect(
      world.server.writes.map(\.route) == [
        "DELETE dive/\(dive.uuidString.lowercased())",
        "DELETE trip/\(trip.uuidString.lowercased())",
        "DELETE dive-site/\(site.uuidString.lowercased())",
      ])
    #expect(outbox.items.isEmpty)
  }

  @Test func aRecordAlreadyGoneIsADeleteDone() async throws {
    let world = try OutboxWorld()
    try await world.load()
    world.server.override { request, _ in
      request.route.hasPrefix("DELETE ") ? .status(404, "Not found") : nil
    }
    let outbox = world.outbox()
    try outbox.queue(.deleteDive(.server(Self.dive)))
    await outbox.settled()
    #expect(outbox.items.isEmpty)
  }

  @Test func aRefusedDeleteOffersDiscardAlone() async throws {
    let world = try OutboxWorld()
    try await world.load()
    world.server.override { request, _ in
      request.route.hasPrefix("DELETE ") ? .status(403, "Not yours") : nil
    }
    let outbox = world.outbox()
    try outbox.queue(.deleteTrip(trip))
    await outbox.settled()
    let item = try #require(outbox.items.first)
    #expect(item.isFailed && !item.isEditable && item.isDiscardable)
  }

  @Test func aDeleteTakesTheWritesWaitingForTheRecordWithIt() async throws {
    let world = try OutboxWorld()
    try await world.load()
    world.server.override { request, _ in
      request.route.hasPrefix("PATCH ") ? .status(422, "Name taken") : nil
    }
    let outbox = world.outbox()
    try outbox.queue(.updateTrip(trip, TripUpdate(name: "Taken")))
    await outbox.settled()
    #expect(outbox.items.first?.isFailed == true)

    let form = try form(outbox)
    #expect(form.canDelete)
    #expect(form.delete())
    await outbox.settled()
    #expect(outbox.items.isEmpty)
    #expect(world.server.writes.last?.route.hasPrefix("DELETE trip/") == true)
  }

  @Test func aLandedDeleteForgetsTheDive() async throws {
    let world = try OutboxWorld()
    try await world.load()
    let detail = DiveDetailModel(session: world.session, diveUUID: Self.dive)
    await detail.load()
    let stores = try #require(AccountStores.current(world.session))
    #expect(stores.cache.dive(Self.dive) != nil)

    let outbox = world.outbox()
    try outbox.queue(.deleteDive(.server(Self.dive)))
    await outbox.settled()
    #expect(stores.cache.dive(Self.dive) == nil)
  }

  @Test func deleteDiveQueuesTheDeleteAndDropsTheEditKeptForIt() async throws {
    let world = try OutboxWorld()
    try await world.load()
    world.offline()
    let detail = DiveDetailModel(session: world.session, diveUUID: Self.dive)
    world.online()
    await detail.load()
    world.offline()
    let form = DiveFormModel(session: world.session, mode: .edit(Self.dive))
    await form.start()
    await form.settled()
    #expect(form.canDelete)
    form.change { $0.notes = "Kept" }
    form.leave()
    #expect(DraftStore<DiveEditDraft>(session: world.session)?.load(.server(Self.dive)) != nil)

    form.deleteDive()
    #expect(form.isDone && form.isDeleted)
    #expect(form.outbox.items.map(\.operation) == [.deleteDive(.server(Self.dive))])
    #expect(DraftStore<DiveEditDraft>(session: world.session)?.load(.server(Self.dive)) == nil)
    await form.settled()
  }

  @Test func onlyAnEditOffersDelete() async throws {
    let world = try OutboxWorld()
    try await world.load()
    #expect(!DiveFormModel(session: world.session, mode: .create).canDelete)
    #expect(!DiveFormModel(session: world.session, mode: .failed(UUID())).canDelete)
  }

  // MARK: - Lists

  @Test func aQueuedDeleteLeavesTheListAndADiscardBringsItBack() async throws {
    let world = try OutboxWorld()
    try await world.load()
    let page = try tripsPage()
    world.server.override { request, _ in request.route == "GET trips" ? .json(page) : nil }
    let list = PagedList<TripRead>(session: world.session, cache: .trips) { client, page, count in
      try await client.trips(page: page, itemsPerPage: count)
    }
    await list.load()
    #expect(list.items.map(\.uuid) == [Self.tripUUID])

    world.offline()
    let outbox = world.outbox()
    let item = try outbox.queue(.deleteTrip(trip))
    #expect(list.items.isEmpty)
    #expect(list.phase == .loaded)

    outbox.discard(item.id)
    #expect(list.items.map(\.uuid) == [Self.tripUUID])
    await outbox.settled()
  }

  @Test func aLandedDeleteStaysOffTheListWhileItsPagesStillHoldIt() async throws {
    let world = try OutboxWorld()
    try await world.load()
    let page = try tripsPage()
    world.server.override { request, _ in request.route == "GET trips" ? .json(page) : nil }
    let list = PagedList<TripRead>(session: world.session, cache: .trips) { client, page, count in
      try await client.trips(page: page, itemsPerPage: count)
    }
    await list.load()

    let outbox = world.outbox()
    try outbox.queue(.deleteTrip(trip))
    await outbox.settled()
    await list.reloading?.value
    #expect(list.items.isEmpty)
  }

  @Test func aRefusedDeleteComesBackToTheList() async throws {
    let world = try OutboxWorld()
    try await world.load()
    let page = try tripsPage()
    world.server.override { request, _ in
      if request.route == "GET trips" { return .json(page) }
      return request.route.hasPrefix("DELETE ") ? .status(403, "Not yours") : nil
    }
    let list = PagedList<TripRead>(session: world.session, cache: .trips) { client, page, count in
      try await client.trips(page: page, itemsPerPage: count)
    }
    await list.load()

    let outbox = world.outbox()
    try outbox.queue(.deleteTrip(trip))
    await outbox.settled()
    #expect(list.items.map(\.uuid) == [Self.tripUUID])
  }

  // MARK: - The page

  @Test func thePageSaysAnEditWaitsAndReadsTheTripOnceItLands() async throws {
    let world = try OutboxWorld()
    try await world.load()
    let read = try KitFixture.text("trip")
    world.server.override { request, index in
      if request.route.hasPrefix("PATCH "), index == 0 { throw URLError(.notConnectedToInternet) }
      guard request.route.hasPrefix("GET trip/") else { return nil }
      let name = index == 0 ? "Dahab" : "Dahab again"
      return .json(read.replacingOccurrences(of: "Dahab 2026 (September)", with: name))
    }
    let model = TripDetailModel(session: world.session, tripUUID: Self.tripUUID)
    await model.load()
    #expect(!model.hasPendingEdit)

    let outbox = world.outbox()
    try outbox.queue(.updateTrip(trip, TripUpdate(name: "Dahab again")))
    await outbox.settled()
    #expect(model.hasPendingEdit)

    outbox.syncNow()
    await outbox.settled()
    await model.reloading?.value
    #expect(!model.hasPendingEdit)
    guard case .loaded(let trip) = model.phase else {
      Issue.record("The trip left the page")
      return
    }
    #expect(trip.name == "Dahab again")
  }

  @Test func aSitesPageReadsItsSiteOnceAnEditLands() async throws {
    let world = try OutboxWorld()
    try await world.load()
    let read = try KitFixture.text("dive-site")
    let site = try KitFixture.decode(DiveSiteRead.self, "dive-site")
    world.server.override { request, index in
      guard request.route.hasPrefix("GET dive-site/") else { return nil }
      return .json(
        read.replacingOccurrences(of: "Tiger Reef", with: index == 0 ? "Tiger Reef" : "Lighthouse"))
    }
    let model = DiveSiteDetailModel(session: world.session, siteUUID: site.uuid)
    await model.load()

    var update = DiveSiteUpdate()
    update.name = "Lighthouse"
    let outbox = world.outbox()
    try outbox.queue(.updateDiveSite(.server(site.uuid), update))
    await outbox.settled()
    await model.reloading?.value
    guard case .loaded(let shown) = model.phase else {
      Issue.record("The site left the page")
      return
    }
    #expect(shown.name == "Lighthouse")
  }

  // MARK: - Words

  @Test func theQueueNamesItsNewWrites() throws {
    func title(_ operation: OutboxOperation) -> String {
      PendingText.title(of: OutboxItem(operation: operation, sequence: 0, marked: false))
    }
    #expect(title(.deleteDive(trip)) == "A deleted dive")
    #expect(title(.deleteTrip(trip)) == "A deleted trip")
    #expect(title(.deleteDiveSite(trip)) == "A deleted dive site")
    #expect(title(.updateTrip(trip, TripUpdate(notes: "Windy"))) == "Changes to a trip")
    #expect(title(.updateTrip(trip, TripUpdate(name: "Dahab"))) == "Changes to trip: Dahab")
    #expect(title(.updateDiveSite(trip, DiveSiteUpdate())) == "Changes to a dive site")

    let items = [
      OutboxItem(operation: .deleteDive(trip), sequence: 0, marked: false),
      OutboxItem(operation: .deleteTrip(trip), sequence: 1, marked: false),
    ]
    #expect(PendingText.waiting(items) == "2 deletions waiting to sync")
  }
}
