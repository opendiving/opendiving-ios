import Foundation
import Testing

@testable import OpenDivingKit

/// A record sheet queues its create and hands back the ref to select; reopened on a refused
/// item, it shows the server's sentence and re-queues the same item.
@MainActor
struct RecordSheetModelTests {
  @Test func savingQueuesTheCreateAndReturnsItsLocalRef() async throws {
    let world = try OutboxWorld()
    try await world.load()
    world.offline()
    let outbox = world.outbox()
    let sheet = RecordSheetModel(outbox: outbox, values: PersonFormValues(name: "Alex M."))

    let ref = try #require(sheet.save())
    #expect(ref.isLocal)
    #expect(outbox.items.map(\.creates) == [ref])
    #expect(outbox.items.first?.operation == .createPerson(PersonCreate(name: "Alex M.")))
    await outbox.settled()
  }

  @Test func anInvalidFormQueuesNothingAndSaysWhyOnceTried() async throws {
    let world = try OutboxWorld()
    try await world.load()
    world.offline()
    let outbox = world.outbox()
    let sheet = RecordSheetModel(outbox: outbox, values: GearItemFormValues())
    #expect(sheet.message("name") == nil)

    #expect(sheet.save() == nil)
    #expect(sheet.message("name") == "Gear name is required")
    #expect(outbox.items.isEmpty)
    sheet.values.name = "MK25 EVO"
    #expect(sheet.issues.isEmpty)
  }

  @Test func aRefusedCreateReopensWithTheServersSentenceAndIsQueuedAgain() async throws {
    let world = try OutboxWorld()
    try await world.load()
    world.offline()
    let outbox = world.outbox()
    let first = RecordSheetModel(
      outbox: outbox, values: DiveSiteFormValues(name: "Canyon", latitude: "28,5", longitude: "34"))
    let ref = try #require(first.save())
    await outbox.settled()
    world.server.override { request, _ in
      request.route == "POST dive-site" ? .status(422, "A site of that name exists here.") : nil
    }
    outbox.syncNow()
    await outbox.settled()
    let item = try #require(outbox.items.first)
    #expect(item.isFailed)

    let reopened = RecordSheetModel(
      outbox: outbox, values: DiveSiteFormValues(), failedItem: item.id)
    #expect(reopened.isReopened)
    #expect(reopened.failure == "A site of that name exists here.")
    #expect(reopened.values.name == "Canyon")
    #expect(reopened.values.latitude == "28.5")
    reopened.values.name = "Canyon North"
    world.offline()
    #expect(reopened.save() == ref)
    #expect(outbox.items.map(\.id) == [item.id])
    #expect(outbox.items.first?.isPending == true)
    if case .createDiveSite(let body) = outbox.items.first?.operation {
      #expect(body.name == "Canyon North")
    } else {
      Issue.record("not a site create")
    }
    await outbox.settled()
  }

  @Test func anItemDiscardedWhileOpenIsNotQueuedAgain() async throws {
    let world = try OutboxWorld()
    try await world.load()
    world.offline()
    let outbox = world.outbox()
    let item = try outbox.queue(.createPerson(PersonCreate(name: "Sam")))
    let sheet = RecordSheetModel(outbox: outbox, values: PersonFormValues(), failedItem: item.id)
    outbox.discard(item.id)

    #expect(sheet.save() == nil)
    #expect(sheet.saveError == "This was discarded meanwhile, so nothing was saved.")
    #expect(outbox.items.isEmpty)
    await outbox.settled()
  }

  @Test func saveAsSetReplacesTheSetPicked() async throws {
    let world = try OutboxWorld()
    try await world.load()
    world.offline()
    let outbox = world.outbox()
    let set = RecordRef.server(UUID())
    let items = [RecordRef.server(UUID())]
    let sheet = RecordSheetModel(
      outbox: outbox,
      values: GearSetSaveValues(
        form: GearSetFormValues(name: "Warm water rec", items: items), target: set))

    #expect(sheet.save() == set)
    #expect(
      outbox.items.first?.operation
        == .updateGearSet(
          set, GearSetUpdate(name: "Warm water rec", weight: .null, gearItems: items)))
    await outbox.settled()
  }

  // MARK: Reopening

  @Test func everyFormReadsBackTheBodyItQueued() throws {
    let person = RecordRef.local(UUID())
    let contact = RecordRef.server(UUID())
    let place = LocationWrite(name: "Dahab, South Sinai, Egypt", latitude: 28.5, longitude: 34.5)
    let checks: [(any RecordSheetValues)] = [
      DiveSiteFormValues(
        name: "Blue Hole", otherNames: ["El Bells"], location: place, latitude: "28.5722",
        longitude: "-34.5372", depthFrom: 5, depthTo: 30, waterType: "salt", altitude: 0,
        entryTypes: ["shore"], tags: ["arch"],
        externalIds: [ExternalIdWrite(registry: "openstreetmap", identifier: "node/1")],
        notes: "Busy"),
      PersonFormValues(name: "Alex", username: "alexm", email: "a@b.co", phone: "1", notes: ""),
      TripFormValues(
        name: "Red Sea", parts: [TripPartFormValues(location: place, accommodation: contact)],
        people: [PersonReference(person: person, role: "buddy")], notes: "n"),
      CourseFormValues(
        name: "AOW", agency: "other", agencyOther: "FFESSM", status: "planned",
        instructor: person, instructorNumber: "42", contact: contact,
        people: [PersonReference(person: .server(UUID()), role: "student")]),
      ContactFormValues(
        name: "Blue Ocean", roles: ["dive_center"], website: "https://blueocean.com",
        city: "Dahab", country: "Egypt", latitude: "28.5", longitude: "34.5"),
      GearItemFormValues(
        name: "Tank", type: "cylinder", volume: 11.1, workingPressure: 232, material: "steel"),
      GearSetSaveValues(form: GearSetFormValues(name: "Set", weight: 6, items: [contact])),
      GearSetSaveValues(form: GearSetFormValues(name: "Set", items: [contact]), target: contact),
    ]
    for values in checks {
      #expect(try roundTrips(values))
    }
  }

  @Test func aTripQueuedWithNoPartsReopensWithOneToFillIn() throws {
    let values = try #require(
      TripFormValues(reopening: .createTrip(TripCreate(name: "Weekend"))))
    #expect(values.parts == [TripPartFormValues()])
  }

  @Test func aFormReopensOnlyAWriteOfItsOwnKind() {
    #expect(PersonFormValues(reopening: .createGearItem(GearItemCreate(name: "Fins"))) == nil)
  }

  private func roundTrips<Values: RecordSheetValues>(_ values: Values) throws -> Bool {
    let operation = try values.operation()
    guard let reopened = Values(reopening: operation) else { return false }
    return try reopened.operation() == operation
  }
}
