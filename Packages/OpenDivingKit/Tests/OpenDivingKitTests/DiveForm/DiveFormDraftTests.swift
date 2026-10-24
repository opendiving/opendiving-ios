import Foundation
import OpenDivingKit
import Testing

/// A dive draft is the server's shape and an edit draft the phone's.
struct DiveFormDraftTests {
  static let site = RecordRef.server(UUID(uuidString: "01a30000-0000-7000-8000-0000000000b1")!)
  static let set = RecordRef.server(UUID(uuidString: "01a14b2e-0c3d-7a10-9f00-9a2b3c4d5e6f")!)
  static let item = RecordRef.server(UUID(uuidString: "01a14b2e-0c3d-7a10-9f00-5a2b3c4d5e6f")!)
  static let buddy = RecordRef.server(UUID(uuidString: "01a30000-0000-7000-8000-0000000000e1")!)

  static var halfFilled: DiveFormValues {
    DiveFormValues(
      startTime: DiveTimestamp(wireValue: "2026-10-24T07:30:00+03:00"), submergedTime: "45:00",
      weight: 4, entryType: "boat", diveSites: [site], gearItems: [item],
      people: [PersonReference(person: buddy, role: "buddy")],
      tanks: [TankValues(volume: 11.1, startPressure: 200, oxygen: 32, helium: 0)])
  }

  /// The draft as the API stores and reads it back: every member, null where the write left it
  /// out (`DiveDraftValuesRead`).
  static func asServerRead(_ draft: DiveDraftWrite) throws -> DiveDraftRead {
    let sent =
      try JSONSerialization.jsonObject(
        with: APICoding.requestEncoder().encode(draft)) as! [String: Any]
    var values = sent["values"] as! [String: Any]
    for key in [
      "dive_number", "start_time", "submerged_time", "max_depth", "avg_depth",
      "bottom_temperature", "visibility", "weight", "water_type", "altitude", "type", "rating",
      "air_temperature", "current", "waves", "weather", "entry_type", "boat_name", "notes",
      "trip_uuid", "course_uuid", "contact_uuid", "mixtures", "dive_site_uuids",
      "gear_item_uuids", "sightings", "people", "tags",
    ] where values[key] == nil {
      values[key] = NSNull()
    }
    let read: [String: Any] = [
      "uuid": "01a40000-0000-7000-8000-000000000001",
      "created_at": "2026-10-24T04:30:00Z", "updated_at": "2026-10-24T04:31:00Z",
      "gear_set_uuid": sent["gear_set_uuid"] ?? NSNull(), "values": values,
    ]
    return try APICoding.decoder().decode(
      DiveDraftRead.self, from: JSONSerialization.data(withJSONObject: read))
  }

  @Test func aHalfFilledFormRoundTripsThroughTheServer() throws {
    let draft = Self.halfFilled.draft(gearSet: Self.set)
    #expect(draft.values.notes == nil)
    #expect(draft.values.diveNumber == nil)
    #expect(draft.values.submergedTime == 2700)
    let read = try Self.asServerRead(draft)
    #expect(read.gearSetUuid == Self.set.serverUUID)
    #expect(DiveFormValues(draft: read.values) == Self.halfFilled)
    #expect(read.write == draft)
  }

  /// What has no place in a draft is left out rather than refused by the server.
  @Test func whatADraftCannotHoldIsLeftOut() {
    var values = Self.halfFilled
    values.submergedTime = "45:"
    values.startTime = DiveTimestamp(wireValue: "2026-10-24T07:30:00")
    let draft = values.draft(gearSet: nil)
    #expect(draft.values.submergedTime == nil)
    #expect(draft.values.startTime == nil)
    #expect(draft.gearSet == nil)
  }

  @Test func anEmptyFormIsAnEmptyDraft() {
    #expect(DiveFormValues().draft(gearSet: nil) == DiveDraftWrite())
  }

  @Test func aDraftKeepsTheTankAsTyped() {
    var tank = TankValues(oxygen: 21, helium: 0)
    let vessel = GearItemInfo(ref: Self.item, name: "AL80", type: "cylinder", volume: 11.1)
    tank.cylinder = vessel.ref
    tank.vessel = vessel
    let values = DiveFormValues(tanks: [tank])
    #expect(values.draft(gearSet: nil).values.mixtures?[0].volume == nil)
    #expect(values.draft(gearSet: nil).values.mixtures?[0].gearItem == Self.item)
  }

  // MARK: The edit draft

  static let localSite = RecordRef.local(UUID())
  static let localPerson = RecordRef.local(UUID())
  static let localTrip = RecordRef.local(UUID())

  static func editNamingLocalRecords() throws -> DiveEditDraft {
    var edit = DiveEditDraft(
      editing: try KitFixture.decode(DiveReadWithMixtures.self, "dive-edit"))
    edit.values.diveSites.append(localSite)
    edit.values.people.append(PersonReference(person: localPerson, role: "guide"))
    edit.values.trip = localTrip
    return edit
  }

  @Test func anEditDraftIsKeptAndReadBack() throws {
    let edit = try Self.editNamingLocalRecords()
    let kept = try APICoding.encoder().encode(edit)
    #expect(try APICoding.decoder().decode(DiveEditDraft.self, from: kept) == edit)
  }

  @Test func landedCreatesRewriteTheValuesAndNotTheBaseline() throws {
    var edit = try Self.editNamingLocalRecords()
    let baseline = edit.baseline
    let named: [RecordRef: RecordRef] = [
      Self.localSite: .server(UUID()), Self.localPerson: .server(UUID()),
      Self.localTrip: .server(UUID()),
    ]
    edit.rewriteRefs { named[$0] ?? $0 }
    #expect(edit.baseline == baseline)
    #expect(edit.values.diveSites == [Self.site, named[Self.localSite]!])
    #expect(
      edit.values.people.last == PersonReference(person: named[Self.localPerson]!, role: "guide"))
    #expect(edit.values.trip == named[Self.localTrip])
    let update = try edit.update()
    #expect(update.trip == .value(named[Self.localTrip]!))
    #expect(update.diveSites == [Self.site, named[Self.localSite]!])
  }

  @Test func aDroppedServerSiteLeavesTheValuesAndTheDiffSendsTheShorterList() throws {
    var edit = DiveEditDraft(editing: try KitFixture.decode(DiveReadWithMixtures.self, "dive-edit"))
    edit.rewriteRefs { $0 == Self.site ? nil : $0 }
    #expect(edit.values.diveSites.isEmpty)
    #expect(edit.baseline.diveSites.map(\.ref) == [Self.site])
    #expect(try edit.update().diveSites == [])
  }

  @Test func aDroppedCylinderUnlinksTheTank() throws {
    var edit = DiveEditDraft(editing: try KitFixture.decode(DiveReadWithMixtures.self, "dive-edit"))
    let cylinder = edit.values.tanks[0].cylinder
    edit.rewriteRefs { $0 == cylinder ? nil : $0 }
    #expect(edit.values.tanks[0].cylinder == nil)
    #expect(edit.values.tanks[0].vessel == nil)
  }
}
