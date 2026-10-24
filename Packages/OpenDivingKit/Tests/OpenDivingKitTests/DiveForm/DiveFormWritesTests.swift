import Foundation
import OpenDivingKit
import Testing

/// `toCreate()` against the web's `buildDiveCreate` and `diff(from:)` against a `buildDiveUpdate`
/// that sends only what changed, over `dive-edit.json` — a dive the weather fetch filled the
/// air temperature and the weather of.
struct DiveFormWritesTests {
  let dive: DiveReadWithMixtures

  init() throws {
    dive = try KitFixture.roundTrip(DiveReadWithMixtures.self, "dive-edit")
  }

  @Test func theReadCarriesWhatTheFetchFilled() {
    #expect(dive.conditions?.filled.airTemperature == 29.4)
    #expect(dive.conditions?.filled.weather == "clear")
    #expect(dive.conditions?.filled.waves == nil)
  }

  @Test func aDiveReadWithoutConditionsHasNone() throws {
    #expect(try KitFixture.decode(DiveReadWithMixtures.self, "dive-detail").conditions == nil)
  }

  @Test func theEditFormOpensOnTheDiveFieldForField() {
    let values = DiveFormValues(editing: dive)
    #expect(values.submergedTime == "45:30")
    #expect(values.boatName == "Sea Example")
    #expect(values.trip == .server(dive.tripUuid!))
    #expect(values.diveSites == dive.diveSites.map(\.ref))
    #expect(values.tanks[0].cylinder == dive.mixtures[0].gearItem?.ref)
    #expect(values.tanks[0].shownVolume == 11.1)
    #expect(values.tanks[1].gasNumber == 1)
    #expect(values.sightings == [SightingWrite(speciesUuid: dive.sightings[0].uuid, count: 1)])
  }

  @Test func anUntouchedEditSendsNothing() throws {
    #expect(try DiveFormValues(editing: dive).diff(from: dive).isEmpty)
  }

  @Test func anEditOfOneFieldSendsThatField() throws {
    var values = DiveFormValues(editing: dive)
    values.notes = "Two turtles."
    var expected = DiveUpdate()
    expected.notes = "Two turtles."
    #expect(try values.diff(from: dive) == expected)
  }

  @Test func aDiveTimeRetypedAsTheSameSecondsIsNoChange() throws {
    var values = DiveFormValues(editing: dive)
    values.submergedTime = "45:30"
    #expect(try values.diff(from: dive).isEmpty)
    values.submergedTime = "46"
    #expect(try values.diff(from: dive).submergedTime == 2760)
  }

  @Test func anEditOfAListSendsTheWholeList() throws {
    var values = DiveFormValues(editing: dive)
    values.tanks[1].endPressure = 120
    let update = try values.diff(from: dive)
    #expect(update.mixtures?.count == 2)
    #expect(update.mixtures?[1].endPressure == 120)
    // The linked tank's blank volume goes as its vessel's capacity, as the web sends it.
    #expect(update.mixtures?[0].volume == 11.1)
    #expect(update.mixtures?[0].gearItem == dive.mixtures[0].gearItem?.ref)
    #expect(update.diveSites == nil)
    #expect(update.people == nil)
    var only = DiveUpdate()
    only.mixtures = update.mixtures
    #expect(update == only)
  }

  @Test func aClearedReferenceIsNull() throws {
    var values = DiveFormValues(editing: dive)
    values.trip = nil
    values.maxDepth = nil
    values.waterType = nil
    values.boatName = "   "
    let update = try values.diff(from: dive)
    #expect(update.trip == .null)
    #expect(update.maxDepth == .null)
    #expect(update.waterType == .null)
    #expect(update.boatName == .null)
    #expect(update.course == .absent)
  }

  /// The API drops a null for a field the fetch filled, so the phone queues none.
  @Test func aClearedFetchedFieldIsNotSent() throws {
    var values = DiveFormValues(editing: dive)
    values.airTemperature = nil
    values.weather = nil
    values.waves = nil
    let update = try values.diff(from: dive)
    #expect(update.airTemperature == .absent)
    #expect(update.weather == .absent)
    // Not the fetch's: the diver's own, and clearing it clears it.
    #expect(update.waves == .null)
  }

  @Test func aReplacedFetchedFieldIsSent() throws {
    var values = DiveFormValues(editing: dive)
    values.weather = "overcast"
    values.airTemperature = 27
    let update = try values.diff(from: dive)
    #expect(update.weather == .value("overcast"))
    #expect(update.airTemperature == .value(27))
  }

  @Test func anInvalidEditIsRefusedWithTheSentence() {
    var values = DiveFormValues(editing: dive)
    values.rating = 6
    #expect(
      throws: FormInvalid(issues: [
        FormIssue(field: "rating", message: "Rating must be between 1 and 5")
      ])
    ) {
      try values.diff(from: dive)
    }
  }

  /// `buildDiveCreate`: empty selects and a blank boat name left out, the boat name trimmed,
  /// each tank normalised, the dive time in seconds.
  @Test func aCreateIsTheWebsCreate() throws {
    let cylinder = dive.mixtures[0].gearItem!
    let values = DiveFormValues(
      diveNumber: 215, startTime: DiveTimestamp(wireValue: "2026-10-21T08:00:00+03:00"),
      submergedTime: "52", maxDepth: 18.3, entryType: "boat", boatName: "  Legend ",
      trip: .local(UUID(uuidString: "01a30000-0000-7000-8000-0000000000f1")!),
      tanks: [
        TankValues(oxygen: 32, helium: 0, cylinder: cylinder.ref, vessel: cylinder),
        TankValues(volume: 12, startPressure: 210, oxygen: 21, helium: 0, gasNumber: 3),
      ])
    let create = try values.toCreate()
    #expect(create.submergedTime == 3120)
    #expect(create.boatName == "Legend")
    #expect(create.waterType == nil)
    #expect(create.notes == "")
    #expect(create.mixtures[0].volume == 11.1)
    #expect(create.mixtures[0].gearItem == cylinder.ref)
    #expect(create.mixtures[1].gasNumber == 3)
    #expect(create.trip == values.trip)
    var blank = values
    blank.boatName = "   "
    #expect(try blank.toCreate().boatName == nil)
  }

  @Test func anInvalidCreateIsRefused() {
    let values = DiveFormValues(diveNumber: 1, submergedTime: "45")
    #expect(
      throws: FormInvalid(issues: [
        FormIssue(field: "start_time", message: "Start time is required")
      ])
    ) {
      try values.toCreate()
    }
  }
}
