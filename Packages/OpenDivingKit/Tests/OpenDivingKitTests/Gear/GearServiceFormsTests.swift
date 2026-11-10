import Foundation
import Testing

@testable import OpenDivingKit

/// The service card's rows and its two forms' rules say what the web's do: rows from the web's
/// `gear-service.test.ts`, `validations/gear-service.test.ts` and the dialogs' and card's render
/// tests at its pin.
@MainActor
struct GearServiceFormsTests {
  private static let item = UUID(uuidString: "01a14b2e-0c3d-7a10-9f00-1a2b3c4d5e6f")!
  private var gearItem: RecordRef { .server(Self.item) }
  private let today = CalendarDate(iso8601: "2026-08-10")!

  private func schedule(_ overrides: [String: Any] = [:]) throws -> GearServiceScheduleRead {
    try decode(GearServiceScheduleRead.self, "gear-service-schedule", overrides)
  }

  private func record(_ overrides: [String: Any] = [:]) throws -> GearServiceRecordRead {
    try decode(GearServiceRecordRead.self, "gear-service-record", overrides)
  }

  private func decode<T: Decodable>(_ type: T.Type, _ name: String, _ overrides: [String: Any])
    throws -> T
  {
    var object = try #require(
      JSONSerialization.jsonObject(with: KitFixture.data(name)) as? [String: Any])
    object.merge(overrides) { $1 }
    return try APICoding.decoder().decode(
      type, from: JSONSerialization.data(withJSONObject: object))
  }

  private func scheduleValues(_ months: Int? = 12) -> ServiceScheduleFormValues {
    ServiceScheduleFormValues(
      gearItem: gearItem, startsOn: CalendarDate(iso8601: "2026-01-01"), intervalMonths: months)
  }

  private func messages(_ values: ServiceScheduleFormValues) -> [String] {
    values.issues.map(\.message)
  }

  // MARK: - Presets

  @Test func theSchedulePresetsAreTheWebs() {
    #expect(
      ServiceSchedulePreset.defaults(forGearType: "cylinder") == [
        ServiceSchedulePreset(kind: "visual_inspection", intervalMonths: 12),
        ServiceSchedulePreset(kind: "hydrostatic_test", intervalMonths: 60),
      ])
    #expect(
      ServiceSchedulePreset.defaults(forGearType: "regulator") == [
        ServiceSchedulePreset(kind: "service", intervalMonths: 12, intervalDives: 100)
      ])
    #expect(
      ServiceSchedulePreset.defaults(forGearType: "wing") == [
        ServiceSchedulePreset(kind: "service", intervalMonths: 12)
      ])
    for type in ["mask", "backplate", "rebreather", "scooter", "transmitter", "", "hookah"] {
      #expect(ServiceSchedulePreset.defaults(forGearType: type).isEmpty)
    }
    #expect(ServiceSchedulePreset.defaults(forGearType: nil).isEmpty)
  }

  @Test func aNewScheduleStartsFromTheFirstPresetInServiceToday() {
    let cylinder = ServiceScheduleFormValues(gearItem: gearItem, gearType: "cylinder", today: today)
    #expect(cylinder.kind == "visual_inspection")
    #expect(cylinder.intervalMonths == 12)
    #expect(cylinder.intervalDives == nil)
    #expect(cylinder.startsOn == today)
    let scooter = ServiceScheduleFormValues(gearItem: gearItem, gearType: "scooter", today: today)
    #expect(scooter.kind == "service")
    #expect(scooter.intervalMonths == nil)
    #expect(scooter.intervalHours == nil)
  }

  // MARK: - Schedule rules

  @Test func aScheduleNeedsOneIntervalOfAnyOfTheThree() {
    #expect(scheduleValues().issues.isEmpty)
    var dives = scheduleValues(nil)
    dives.intervalDives = 100
    #expect(dives.issues.isEmpty)
    var hours = scheduleValues(nil)
    hours.intervalHours = 50
    #expect(hours.issues.isEmpty)
    let none = scheduleValues(nil)
    #expect(none.issues.first?.field == "interval_months")
    #expect(messages(none) == ["Set an interval in months, in dives or in hours of diving"])
  }

  @Test func eachIntervalIsBoundedWhereTheAPIBoundsIt() {
    #expect(messages(scheduleValues(1_200)).isEmpty)
    #expect(messages(scheduleValues(1_201)) == ["Interval in months cannot exceed 1,200"])
    #expect(messages(scheduleValues(0)) == ["Interval in months must be greater than zero"])
    #expect(messages(scheduleValues(-12)) == ["Interval in months must be greater than zero"])
    var dives = scheduleValues()
    dives.intervalDives = 1_000_001
    #expect(messages(dives) == ["Interval in dives cannot exceed 1,000,000"])
    var hours = scheduleValues()
    hours.intervalHours = 1_000_000
    #expect(messages(hours).isEmpty)
    hours.intervalHours = 1_000_001
    #expect(messages(hours) == ["Interval in hours cannot exceed 1,000,000"])
  }

  @Test func aScheduleNeedsItsDayAndBoundsItsLabel() {
    var values = scheduleValues()
    values.startsOn = nil
    values.label = String(repeating: "x", count: 121)
    #expect(
      messages(values) == ["Label cannot exceed 120 characters", "An in-service date is required"])
  }

  @Test func aNewScheduleSendsItsLabelTrimmedAndItsIntervals() throws {
    var values = scheduleValues(nil)
    values.label = "  First stage  "
    values.intervalHours = 50
    let body = try values.toCreate()
    #expect(body.label == "First stage")
    #expect(body.gearItem == gearItem)
    #expect(body.intervalMonths == nil)
    #expect(body.intervalHours == 50)
    #expect(ServiceScheduleFormValues(reopening: try values.operation()) == values.trimmedLabel)
  }

  @Test func aScheduleEditSendsWhatChangedAnIntervalClearedAsNull() throws {
    let read = try schedule()
    let before = ServiceScheduleFormValues(editing: read)
    #expect(before.gearItem == gearItem)
    #expect(try before.diff(from: before).isEmpty)
    var after = before
    after.intervalDives = nil
    after.intervalHours = 50
    var expected = GearServiceScheduleUpdate()
    expected.intervalDives = .null
    expected.intervalHours = .value(50)
    #expect(try after.diff(from: before) == expected)
    #expect(before.applying(expected) == after)
    let operation = try #require(try after.update(of: .server(read.uuid), from: before))
    #expect(operation == .updateServiceSchedule(.server(read.uuid), gearItem: gearItem, expected))
    #expect(
      ServiceScheduleFormValues.delete(.server(read.uuid), gearItem: gearItem)
        == .deleteServiceSchedule(.server(read.uuid), gearItem: gearItem))
  }

  @Test func aPauseChangesNothingTheFormShows() throws {
    let values = ServiceScheduleFormValues(editing: try schedule())
    #expect(values.applying(GearServiceScheduleUpdate(active: false)) == values)
  }

  @Test func aTypedIntervalIsAWholeNumberOrNothing() {
    #expect(ServiceScheduleFormValues.interval("12") == 12)
    #expect(ServiceScheduleFormValues.interval(" 7 ") == 7)
    #expect(ServiceScheduleFormValues.interval("") == nil)
    #expect(ServiceScheduleFormValues.interval("1.5") == nil)
  }

  // MARK: - Service rules

  @Test func aServiceNeedsItsDayAndBoundsWhoAndTheNotes() {
    var values = ServiceRecordFormValues(gearItem: gearItem, schedule: nil, today: today)
    #expect(values.servicedOn == today)
    #expect(values.kind == "service")
    #expect(values.issues.isEmpty)
    values.servicedOn = nil
    values.performedBy = String(repeating: "x", count: 256)
    values.notes = String(repeating: "x", count: 100_001)
    #expect(
      values.issues.map(\.message) == [
        "A service date is required", "Serviced by cannot exceed 255 characters",
        "Notes cannot exceed 100,000 characters",
      ])
  }

  @Test func aServiceLoggedAgainstAScheduleTakesItsKindAndLabel() throws {
    let rule = try schedule(["kind": "visual_inspection", "label": "Left"])
    let values = ServiceRecordFormValues(gearItem: gearItem, schedule: rule, today: today)
    let body = try values.toCreate()
    #expect(body.kind == "visual_inspection")
    #expect(body.label == "Left")
    #expect(body.schedule == .server(rule.uuid))
    #expect(body.performedBy == nil)
    #expect(ServiceRecordFormValues(reopening: try values.operation()) == values)
  }

  @Test func aServiceEditSendsWhatChangedTheShopTakenOffAsNull() throws {
    let read = try record()
    let before = ServiceRecordFormValues(editing: read)
    #expect(try before.diff(from: before).isEmpty)
    var after = before
    after.contact = nil
    after.performedBy = ""
    after.notes = "New HP seat and o-rings."
    var expected = GearServiceRecordUpdate()
    expected.contact = .null
    expected.performedBy = .null
    expected.notes = "New HP seat and o-rings."
    #expect(try after.diff(from: before) == expected)
    #expect(before.applying(expected) == after)
  }

  // MARK: - The card

  @Test func aSchedulesRowSaysItsStatusIntervalsAndLastService() throws {
    let row = GearServiceCardContent.row(
      try schedule(["next_due_on": "2026-08-20"]), diveCount: 100, diveTime: 0, today: today)
    #expect(row.kind == "Service")
    #expect(row.status == Badge("Due soon", style: .coral))
    #expect(row.due == "Due in 10 days")
    #expect(row.intervals == "Every 12 months or every 100 dives · last done Sep 1, 2025")
    #expect(row.logLabel == "Log service for Service")
    #expect(row.toggleLabel == "Pause Service schedule")

    let hours = GearServiceCardContent.row(
      try schedule([
        "interval_months": NSNull(), "interval_dives": NSNull(), "interval_hours": 50,
        "last_service_on": NSNull(), "label": "First stage",
      ]), diveCount: 100, diveTime: 0, today: today)
    #expect(hours.intervals == "every 50 hours of diving · never serviced")
    #expect(hours.name == "Service (First stage)")
    #expect(hours.deleteLabel == "Delete Service (First stage) schedule")
  }

  @Test func aPausedScheduleHasNoStatus() throws {
    let row = GearServiceCardContent.row(
      try schedule(["is_active": false]), diveCount: 0, diveTime: 0, today: today)
    #expect(row.isPaused)
    #expect(row.status == nil)
    #expect(row.due == nil)
    #expect(row.toggleLabel == "Resume Service schedule")
  }

  @Test func aServicesRowNamesWhereThenWhoAndTheDay() throws {
    let read = try record(["label": "First stage"])
    let shop = ContactLookupItem(ref: .server(try #require(read.contactUuid)), name: "Blue Ocean")
    let row = GearServiceCardContent.row(read, contacts: [shop])
    #expect(row.date == "Sep 1, 2025")
    #expect(row.servicedBy == "Blue Ocean · Self")
    #expect(row.notes == "New HP seat.")
    #expect(row.name == "Service (First stage) on Sep 1, 2025")
    #expect(row.editLabel == "Edit Service (First stage) on Sep 1, 2025")
    let unnamed = GearServiceCardContent.row(
      try record(["performed_by": NSNull(), "notes": ""]), contacts: [])
    #expect(unnamed.servicedBy == nil)
    #expect(unnamed.notes == nil)
  }

  @Test func aKindThisBuildDoesNotKnowReadsDeSnaked() {
    #expect(GearServiceKinds.label("oxygen_clean") == "Oxygen cleaning")
    #expect(GearServiceKinds.label("ultrasonic_clean") == "Ultrasonic clean")
    #expect(GearServiceKinds.options(including: "service") == GearServiceKinds.all)
    #expect(GearServiceKinds.options(including: "ultrasonic_clean").last == "ultrasonic_clean")
  }

  // MARK: - Through the queue

  @Test func aScheduleEditIsSentToItsRouteAndItsDeleteNamesTheItem() async throws {
    let world = try OutboxWorld()
    try await world.load()
    let outbox = world.outbox()
    let read = try schedule()
    let ref = RecordRef.server(read.uuid)
    let form = RecordSheetModel(
      outbox: outbox, editing: ref, read: ServiceScheduleFormValues(editing: read))
    #expect(form.canDelete)
    form.values.intervalMonths = 24
    #expect(form.save() == ref)
    await outbox.settled()
    let write = try #require(world.server.writes.last)
    #expect(write.route == "PATCH gear-service-schedule/\(read.uuid.uuidString.lowercased())")
    #expect(write.json as NSDictionary == ["interval_months": 24])

    world.offline()
    #expect(form.delete())
    #expect(outbox.items.map(\.operation) == [.deleteServiceSchedule(ref, gearItem: gearItem)])
  }

  @Test func aQueuedServiceWriteForTheItemIsSaidOnItsCard() async throws {
    let world = try OutboxWorld()
    try await world.load()
    world.offline()
    let outbox = world.outbox()
    #expect(!GearServiceCardContent.hasPendingWrite(outbox.items, gearItem: Self.item))
    let form = RecordSheetModel(
      outbox: outbox,
      values: ServiceRecordFormValues(gearItem: gearItem, schedule: nil, today: today))
    #expect(form.save() != nil)
    #expect(GearServiceCardContent.hasPendingWrite(outbox.items, gearItem: Self.item))
    #expect(!GearServiceCardContent.hasPendingWrite(outbox.items, gearItem: UUID()))
  }
}

extension ServiceScheduleFormValues {
  fileprivate var trimmedLabel: Self {
    var next = self
    next.label = label.trimmingCharacters(in: .whitespaces)
    return next
  }
}
