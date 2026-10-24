import Foundation
import OpenDivingKit
import Testing

/// The last-dive prefill against `new-dive-page-content.tsx`'s at `opendiving-web` `d5b2d545`
/// (`prefillFromLastDive`, 240-363), over `dive-edit.json` as the last dive.
struct DiveFormPrefillTests {
  let last: DiveReadWithMixtures
  let now = Date(timeIntervalSince1970: 1_792_400_000)
  let zone = TimeZone(secondsFromGMT: 3 * 3_600)!

  init() throws {
    last = try KitFixture.decode(DiveReadWithMixtures.self, "dive-edit")
  }

  private func carried(hiding hidden: [String] = []) -> DiveFormValues {
    DiveFormValues.carried(
      from: last, number: 215, visibility: DiveFormVisibility(hiddenKeys: hidden), now: now,
      timeZone: zone)
  }

  @Test func whatCarries() {
    let values = carried()
    #expect(values.diveNumber == 215)
    #expect(values.startTime == DiveStart.now(now, in: zone))
    #expect(values.course == .server(last.courseUuid!))
    #expect(values.trip == .server(last.tripUuid!))
    #expect(values.contact == .server(last.contactUuid!))
    #expect(values.entryType == "boat")
    #expect(values.boatName == "Sea Example")
    #expect(values.people == last.people)
    #expect(values.type == "open_circuit")
    #expect(values.waterType == "salt")
    #expect(values.altitude == 0)
    #expect(values.weight == 4)
    // The archived fins are retired gear.
    #expect(values.gearItems == [last.gearItems[0].ref])
  }

  @Test func whatDoesNotCarry() {
    let values = carried()
    #expect(values.diveSites.isEmpty)
    #expect(values.maxDepth == nil)
    #expect(values.avgDepth == nil)
    #expect(values.bottomTemperature == nil)
    #expect(values.airTemperature == nil)
    #expect(values.visibility == nil)
    #expect(values.current == nil)
    #expect(values.waves == nil)
    #expect(values.weather == nil)
    #expect(values.sightings.isEmpty)
    #expect(values.rating == nil)
    #expect(values.tags.isEmpty)
    #expect(values.notes == "")
    #expect(values.submergedTime == "")
  }

  /// The tanks carry their mix and their vessel where it can still be linked, never the
  /// pressures or the source's gas numbers.
  @Test func theTanks() {
    let tanks = carried().tanks
    #expect(tanks.count == 2)
    #expect(tanks[0].cylinder == last.mixtures[0].gearItem?.ref)
    #expect(tanks[0].volume == 11.1)
    #expect(tanks[0].oxygen == 32)
    #expect(tanks[0].po2Limit == 1.4)
    #expect(tanks[0].role == "bottom")
    #expect(tanks[1].cylinder == nil)
    #expect(tanks[1].vessel == nil)
    #expect(tanks[1].volume == 5.7)
    #expect(tanks[1].usage == "staged")
    #expect(
      tanks.allSatisfy { $0.startPressure == nil && $0.endPressure == nil && $0.gasNumber == nil })
  }

  /// A field the account hides starts empty; hiding He writes 0 on every tank.
  @Test func aHiddenFieldStartsEmpty() {
    let values = carried(hiding: ["weight", "trip_uuid", "mixture.helium", "mixture.role"])
    #expect(values.weight == nil)
    #expect(values.trip == nil)
    #expect(values.course != nil)
    #expect(values.tanks.map(\.helium) == [0, 0])
    #expect(values.tanks.allSatisfy { $0.role == nil })
    #expect(carried(hiding: ["mixtures"]).tanks.isEmpty)
  }

  @Test func aNewDiveWithNoLastDive() {
    let values = DiveFormValues.newDive(number: nil, now: now, timeZone: zone)
    #expect(values.diveNumber == nil)
    #expect(values.tanks.isEmpty)
    #expect(values.startTime?.utcOffsetMinutes == 180)
  }
}
