import Foundation
import Testing

@testable import OpenDivingKit

/// The writes to gear, its service, courses, certifications, people and contacts, and the card
/// images, through the queue.
@MainActor
struct MoreWritesQueueTests {
  private static let item = RecordRef.server(
    UUID(uuidString: "01a14b2e-0c3d-7a10-9f00-5a2b3c4d5e6f")!)
  private static let certification = RecordRef.server(
    UUID(uuidString: "01a14b2e-0c3d-7a10-9f00-7a2b3c4d5e6f")!)
  private static let card = CertificationCardUpload(
    side: .front, filename: "front.jpg", contentType: "image/jpeg")

  private static func wire(_ ref: RecordRef) -> String {
    ref.serverUUID!.uuidString.lowercased()
  }

  private static func schedule(for gear: RecordRef) -> GearServiceScheduleCreate {
    GearServiceScheduleCreate(
      gearItem: gear, kind: "service", startsOn: CalendarDate(year: 2026, month: 3, day: 1)!,
      intervalMonths: 12)
  }

  // MARK: - Routes

  @Test func everyWriteGoesToItsRoute() async throws {
    let world = try OutboxWorld()
    try await world.load()
    let outbox = world.outbox()
    let uuid = Self.wire(Self.item)
    let writes: [(OutboxOperation, String)] = [
      (.updatePerson(Self.item, PersonUpdate(name: "Sam")), "PATCH person/\(uuid)"),
      (.updateCourse(Self.item, CourseUpdate()), "PATCH course/\(uuid)"),
      (.updateContact(Self.item, ContactUpdate()), "PATCH contact/\(uuid)"),
      (.updateGearItem(Self.item, GearItemUpdate(archived: true)), "PATCH gear-item/\(uuid)"),
      (.createServiceSchedule(Self.schedule(for: Self.item)), "POST gear-service-schedule"),
      (
        .updateServiceSchedule(
          Self.item, gearItem: Self.item, GearServiceScheduleUpdate(active: false)),
        "PATCH gear-service-schedule/\(uuid)"
      ),
      (
        .updateServiceRecord(Self.item, gearItem: Self.item, GearServiceRecordUpdate()),
        "PATCH gear-service-record/\(uuid)"
      ),
      (
        .createCertification(CertificationCreate(agency: "padi", name: "Rescue Diver")),
        "POST certification"
      ),
      (.updateCertification(Self.item, CertificationUpdate()), "PATCH certification/\(uuid)"),
      (.deleteCertificationFile(Self.item, .back), "DELETE certification/\(uuid)/file/back"),
      (
        .deleteServiceSchedule(Self.item, gearItem: Self.item),
        "DELETE gear-service-schedule/\(uuid)"
      ),
      (.deleteServiceRecord(Self.item, gearItem: Self.item), "DELETE gear-service-record/\(uuid)"),
      (.deleteCertification(Self.item), "DELETE certification/\(uuid)"),
      (.deleteGearSet(Self.item), "DELETE gear-set/\(uuid)"),
      (.deletePerson(Self.item), "DELETE person/\(uuid)"),
      (.deleteCourse(Self.item), "DELETE course/\(uuid)"),
      (.deleteContact(Self.item), "DELETE contact/\(uuid)"),
      (.deleteGearItem(Self.item), "DELETE gear-item/\(uuid)"),
    ]
    for (operation, route) in writes {
      let mark = world.server.mark
      try outbox.queue(operation)
      await outbox.settled()
      #expect(world.server.writes(since: mark).map(\.route) == [route])
    }
    #expect(outbox.items.isEmpty)
  }

  @Test func aPauseSendsOnlyItsSwitch() async throws {
    let world = try OutboxWorld()
    try await world.load()
    let outbox = world.outbox()
    try outbox.queue(
      .updateServiceSchedule(
        Self.item, gearItem: Self.item, GearServiceScheduleUpdate(active: false)))
    await outbox.settled()
    #expect(try #require(world.server.writes.last).json as NSDictionary == ["is_active": false])
  }

  // MARK: - Landing

  @Test func aLandedDeleteForgetsTheKeptPage() async throws {
    let world = try OutboxWorld()
    try await world.load()
    let gear = try KitFixture.decode(GearItemRead.self, "gear-item")
    world.cacheA.writeRecord(gear, .gearItem, fetchedAt: Date())
    let outbox = world.outbox()
    try outbox.queue(.deleteGearItem(.server(gear.uuid)))
    await outbox.settled()
    #expect(world.cacheA.record(.gearItem, gear.uuid) == nil)
  }

  @Test func aDeleteTheServerHasAlreadyDoneIsLanded() async throws {
    let world = try OutboxWorld()
    try await world.load()
    world.server.override { request, _ in
      request.route.hasPrefix("DELETE ") ? .status(404, "Not Found") : nil
    }
    let outbox = world.outbox()
    try outbox.queue(.deleteCourse(Self.item))
    try outbox.queue(.deleteCertificationFile(Self.certification, .back))
    await outbox.settled()
    #expect(outbox.items.isEmpty)
  }

  @Test func aLandedPersonWriteReadsThePeopleAgain() async throws {
    let world = try OutboxWorld()
    try await world.load()
    let before = world.server.count("GET people")
    let outbox = world.outbox()
    try outbox.queue(.updatePerson(Self.item, PersonUpdate(name: "Sam")))
    await outbox.settled()
    #expect(world.server.count("GET people") == before + 1)

    try outbox.queue(.updateCourse(Self.item, CourseUpdate()))
    await outbox.settled()
    #expect(world.server.count("GET people") == before + 1)
  }

  // MARK: - Refusals and 404s

  @Test func anEditOfARecordTheServerNoLongerHasOffersDiscardAlone() async throws {
    let world = try OutboxWorld()
    try await world.load()
    let person = try KitFixture.decode(PersonRead.self, "person")
    world.cacheA.writeRecord(person, .person, fetchedAt: Date())
    world.server.override { request, _ in
      request.route.hasPrefix("PATCH ") ? .status(404, "Not Found") : nil
    }
    let outbox = world.outbox()
    let edit = try outbox.queue(.updatePerson(.server(person.uuid), PersonUpdate(name: "Sam")))
    await outbox.settled()
    let failed = try #require(outbox.item(edit.id))
    #expect(failed.failure?.status == 404)
    #expect(!failed.isEditable)
    #expect(world.cacheA.record(.person, person.uuid) == nil)
  }

  @Test func aRefusedEditIsHeldWithTheServersSentenceAndOffersEdit() async throws {
    let world = try OutboxWorld()
    try await world.load()
    world.server.override { request, _ in
      request.route.hasPrefix("PATCH ") ? .status(422, "Name taken") : nil
    }
    let outbox = world.outbox()
    let edit = try outbox.queue(.updateGearItem(Self.item, GearItemUpdate(archived: true)))
    await outbox.settled()
    let failed = try #require(outbox.item(edit.id))
    #expect(failed.failure?.message == "Name taken")
    #expect(failed.isEditable)
  }

  @Test func aDeleteOffersNoEdit() async throws {
    let world = try OutboxWorld()
    try await world.load()
    world.offline()
    let outbox = world.outbox()
    for operation: OutboxOperation in [
      .deletePerson(Self.item), .deleteCourse(Self.item), .deleteContact(Self.item),
      .deleteGearItem(Self.item), .deleteGearSet(Self.item),
      .deleteServiceSchedule(Self.item, gearItem: Self.item),
      .deleteServiceRecord(Self.item, gearItem: Self.item), .deleteCertification(Self.item),
      .deleteCertificationFile(Self.item, .front),
    ] {
      #expect(!(try outbox.queue(operation)).isEditable)
    }
    await outbox.settled()
  }

  // MARK: - What depends on what

  @Test func aScheduleForGearCreatedOfflineIsSentAfterItUnderTheServersUuid() async throws {
    let world = try OutboxWorld()
    try await world.load()
    world.offline()
    let outbox = world.outbox()
    let gear = try outbox.queue(.createGearItem(GearItemCreate(name: "Regulator")))
    try outbox.queue(.createServiceSchedule(Self.schedule(for: gear.creates!)))
    await outbox.settled()

    world.online()
    let mark = world.server.mark
    outbox.syncNow()
    await outbox.settled()
    #expect(
      world.server.writes(since: mark).map(\.route) == [
        "POST gear-item", "POST gear-service-schedule",
      ])
    let created = try #require(world.server.created.first).uuidString.lowercased()
    #expect(world.server.writes.last?.json["gear_item_uuid"] as? String == created)
  }

  @Test func aRefusedGearCreateHoldsItsSchedule() async throws {
    let world = try OutboxWorld()
    try await world.load()
    let outbox = world.outbox()
    world.offline()
    let gear = try outbox.queue(.createGearItem(GearItemCreate(name: "Regulator")))
    let schedule = try outbox.queue(.createServiceSchedule(Self.schedule(for: gear.creates!)))
    world.server.override { request, _ in
      request.route == "POST gear-item" ? .status(422, "Name taken") : nil
    }
    outbox.syncNow()
    await outbox.settled()
    #expect(outbox.heldBehind(try #require(outbox.item(schedule.id)))?.id == gear.id)
    #expect(world.server.count("POST gear-service-schedule") == 0)
  }

  @Test func discardingAGearCreateWithdrawsWhatCannotGoOnWithoutIt() async throws {
    let world = try OutboxWorld()
    try await world.load()
    world.offline()
    let outbox = world.outbox()
    let gear = try outbox.queue(.createGearItem(GearItemCreate(name: "Regulator")))
    let schedule = try outbox.queue(.createServiceSchedule(Self.schedule(for: gear.creates!)))
    let pause = try outbox.queue(
      .updateServiceSchedule(
        schedule.creates!, gearItem: gear.creates!, GearServiceScheduleUpdate(active: false)))
    let service = try outbox.queue(
      .createServiceRecord(
        GearServiceRecordCreate(
          gearItem: gear.creates!, schedule: schedule.creates!, kind: "service",
          servicedOn: CalendarDate(year: 2026, month: 10, day: 2)!)))
    let set = try outbox.queue(
      .createGearSet(GearSetCreate(name: "Warm", gearItems: [gear.creates!])))

    let effects = outbox.discardEffects(gear.id)
    #expect(Set(effects.withdrawn.map(\.id)) == [schedule.id, pause.id, service.id])
    #expect(effects.released.map(\.id) == [set.id])

    outbox.discard(gear.id)
    #expect(outbox.items.map(\.id) == [set.id])
    #expect(outbox.items.first?.operation == .createGearSet(GearSetCreate(name: "Warm")))
    await outbox.settled()
  }

  @Test func aQueuedDeleteWithdrawsTheWritesThatNeedTheRecord() async throws {
    let world = try OutboxWorld()
    try await world.load()
    world.offline()
    let outbox = world.outbox()
    let schedule = try outbox.queue(.createServiceSchedule(Self.schedule(for: Self.item)))
    try outbox.queue(
      .updateServiceSchedule(
        schedule.creates!, gearItem: Self.item, GearServiceScheduleUpdate(active: false)))
    let edit = try outbox.queue(.updateGearItem(Self.item, GearItemUpdate(archived: true)))
    try outbox.queue(
      .deleteServiceRecord(.server(UUID()), gearItem: Self.item))
    let delete = try outbox.queue(.deleteGearItem(Self.item))
    #expect(outbox.items.map(\.id) == [delete.id])
    #expect(outbox.item(edit.id) == nil)
    await outbox.settled()
  }

  // MARK: - Card images

  @Test func aCardImageIsOnDiskBeforeItIsQueuedAndSentAfterItsCertification() async throws {
    let world = try OutboxWorld()
    try await world.load()
    world.offline()
    let outbox = world.outbox()
    let certification = try outbox.queue(
      .createCertification(CertificationCreate(agency: "padi", name: "Rescue Diver")))
    let image = try outbox.queueCardImage(
      Data("JPG".utf8), as: Self.card, of: certification.creates!)
    let file = world.storesA.cardFile(for: image.id)
    #expect(try Data(contentsOf: file) == Data("JPG".utf8))

    world.online()
    let mark = world.server.mark
    outbox.syncNow()
    await outbox.settled()
    let created = try #require(world.server.created.first).uuidString.lowercased()
    let writes = world.server.writes(since: mark)
    #expect(
      writes.map(\.route) == ["POST certification", "PUT certification/\(created)/file/front"])
    let body = try #require(writes.last?.body)
    #expect(body.range(of: Data("JPG".utf8)) != nil)
    #expect(body.range(of: Data(#"filename="front.jpg""#.utf8)) != nil)
    #expect(body.range(of: Data("Content-Type: image/jpeg".utf8)) != nil)
    #expect(outbox.items.isEmpty)
    #expect(!FileManager.default.fileExists(atPath: file.path))
  }

  @Test func aSecondImageOfASideReplacesTheFirst() async throws {
    let world = try OutboxWorld()
    try await world.load()
    world.offline()
    let outbox = world.outbox()
    let first = try outbox.queueCardImage(Data("one".utf8), as: Self.card, of: Self.certification)
    let back = try outbox.queueCardImage(
      Data("back".utf8),
      as: CertificationCardUpload(side: .back, filename: "b.png", contentType: "image/png"),
      of: Self.certification)
    let removal = try outbox.queue(.deleteCertificationFile(Self.certification, .front))
    let second = try outbox.queueCardImage(Data("two".utf8), as: Self.card, of: Self.certification)
    #expect(outbox.items.map(\.id) == [back.id, second.id])
    #expect(outbox.item(removal.id) == nil)
    #expect(!FileManager.default.fileExists(atPath: world.storesA.cardFile(for: first.id).path))
    await outbox.settled()
  }

  @Test func discardingACardImageRemovesItsBytes() async throws {
    let world = try OutboxWorld()
    try await world.load()
    world.offline()
    let outbox = world.outbox()
    let image = try outbox.queueCardImage(Data("JPG".utf8), as: Self.card, of: Self.certification)
    outbox.discard(image.id)
    #expect(!FileManager.default.fileExists(atPath: world.storesA.cardFile(for: image.id).path))
    await outbox.settled()
  }

  @Test func aCardImageWhoseBytesAreGoneFailsAndIsNotSent() async throws {
    let world = try OutboxWorld()
    try await world.load()
    world.offline()
    let outbox = world.outbox()
    let image = try outbox.queueCardImage(Data("JPG".utf8), as: Self.card, of: Self.certification)
    try FileManager.default.removeItem(at: world.storesA.cardFile(for: image.id))
    world.online()
    outbox.syncNow()
    await outbox.settled()
    #expect(outbox.item(image.id)?.failure?.message == OutboxText.cardImageMissing)
    #expect(world.server.writes.isEmpty)
  }

  @Test func aRefusedCardImageIsHeldWithTheServersSentence() async throws {
    let world = try OutboxWorld()
    try await world.load()
    world.server.override { request, _ in
      request.route.hasPrefix("PUT certification") ? .status(415, "Not an image.") : nil
    }
    let outbox = world.outbox()
    let image = try outbox.queueCardImage(Data("JPG".utf8), as: Self.card, of: Self.certification)
    await outbox.settled()
    let failed = try #require(outbox.item(image.id))
    #expect(failed.failure?.message == "Not an image.")
    #expect(failed.isEditable)
    #expect(FileManager.default.fileExists(atPath: world.storesA.cardFile(for: image.id).path))
  }

  @Test func aCardImageGoesThroughItsOwnQueueing() async throws {
    let world = try OutboxWorld()
    try await world.load()
    let outbox = world.outbox()
    #expect(throws: OutboxModel.OutboxError.cardImageOperation) {
      try outbox.queue(.putCertificationFile(Self.certification, Self.card))
    }
  }

  @Test func aCardImageWrittenBeforeAnotherAccountLoadedMovesWithItsBytes() async throws {
    let first = try OutboxWorld()
    try await first.load()
    let world = try first.relaunched()
    let model = world.outbox()
    let certification = try model.queue(
      .createCertification(CertificationCreate(agency: "padi", name: "Rescue Diver")))
    let image = try model.queueCardImage(
      Data("JPG".utf8), as: Self.card, of: certification.creates!)
    #expect(image.writtenBeforeAccountKnown)

    world.server.signIn(as: OutboxServer.accountB)
    try await world.session.loadAccount()
    model.sessionChanged()

    #expect(world.storesB.items().map(\.id) == [certification.id, image.id])
    #expect(try Data(contentsOf: world.storesB.cardFile(for: image.id)) == Data("JPG".utf8))
    #expect(!FileManager.default.fileExists(atPath: world.storesA.cardFile(for: image.id).path))
    await model.settled()
  }

  // MARK: - A record's page

  @Test func aRecordPageShowsAQueuedEditUntilItLands() async throws {
    let world = try OutboxWorld()
    try await world.load()
    world.offline()
    let outbox = world.outbox()
    let uuid = Self.item.serverUUID!
    let page = RecordPage(session: world.session, person: uuid)
    await page.load()
    #expect(!page.hasPendingEdit)

    try outbox.queue(.updatePerson(Self.item, PersonUpdate(name: "Sam")))
    #expect(page.hasPendingEdit)

    world.online()
    outbox.syncNow()
    await outbox.settled()
    #expect(!page.hasPendingEdit)
  }

  @Test func aQueuedDeleteIsNoPendingEdit() async throws {
    let world = try OutboxWorld()
    try await world.load()
    world.offline()
    let outbox = world.outbox()
    let page = RecordPage(session: world.session, course: Self.item.serverUUID!)
    await page.load()
    try outbox.queue(.deleteCourse(Self.item))
    #expect(!page.hasPendingEdit)
    await outbox.settled()
  }
}
