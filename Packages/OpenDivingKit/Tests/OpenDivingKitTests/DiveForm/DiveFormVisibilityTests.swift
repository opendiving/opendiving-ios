import Foundation
import OpenDivingKit
import Testing

/// The reveal rule's golden rows: `src/lib/dive-form-fields.test.ts` at `opendiving-web`
/// `d5b2d545`, each with its line, the web's form values spelled as the phone holds them.
struct DiveFormVisibilityTests {
  private let trip = RecordRef.server(UUID())

  /// :226-237 — nil, `""` and `[]` are nothing.
  @Test func emptyIsNothing() {
    #expect(DiveFormValues().nonEmptyFields == [])
  }

  /// :241-245 and :190-199 — an end pressure of 0 is a drained cylinder; helium's 0 is what
  /// hiding He writes, and reveals nothing; 30 % does.
  @Test func zeroIsAValueExceptHeliumsZero() {
    #expect(
      DiveFormValues(tanks: [TankValues(endPressure: 0)]).nonEmptyFields == [
        .mixtures, .mixtureEndPressure,
      ])
    #expect(!DiveFormValues(tanks: [TankValues(helium: 0)]).nonEmptyFields.contains(.mixtureHelium))
    #expect(DiveFormValues(tanks: [TankValues(helium: 30)]).nonEmptyFields.contains(.mixtureHelium))
  }

  /// :246-256 — a column any tank records is revealed.
  @Test func aColumnAnyTankHolds() {
    let values = DiveFormValues(tanks: [TankValues(), TankValues(startPressure: 210)])
    #expect(values.nonEmptyFields == [.mixtures, .mixtureStartPressure])
  }

  /// :258-262 — in form order.
  @Test func inFormOrder() {
    #expect(DiveFormValues(notes: "wreck", trip: trip).nonEmptyFields == [.trip, .notes])
  }

  /// `useDiveFormVisibility.ts` `isVisible`: not hidden, or hidden and revealed.
  @Test func hiddenUnlessRevealed() {
    var visibility = DiveFormVisibility(hiddenKeys: ["notes", "trip_uuid"])
    #expect(!visibility.isVisible(.notes))
    #expect(visibility.isVisible(.maxDepth))
    visibility.reveal(holdingValuesIn: DiveFormValues(notes: "wreck"))
    #expect(visibility.isVisible(.notes))
    #expect(visibility.isRevealed(.notes))
    #expect(visibility.isHidden(.notes))
    #expect(!visibility.isVisible(.trip))
    #expect(!visibility.isRevealed(.maxDepth))
  }

  /// :264-289: a failed save puts its fields on screen, a tank's
  /// sentence the tanks with its column, and an always-shown field nothing.
  @Test func aFailedSaveRevealsItsFields() throws {
    var visibility = DiveFormVisibility(
      hiddenKeys: ["altitude", "mixtures", "mixture.end_pressure"])
    let values = DiveFormValues(
      diveNumber: 0, startTime: DiveStart.now(), submergedTime: "45", altitude: 9000,
      tanks: [TankValues(startPressure: 100, endPressure: 200)])
    #expect(throws: FormInvalid.self) { try values.validate(for: .create) }
    do {
      try values.validate(for: .create)
    } catch {
      visibility.reveal(failing: error)
    }
    #expect(visibility.revealed == [.altitude, .mixtures, .mixtureEndPressure])
  }

  /// A hidden field holding a value that came from outside the diver's typing is shown and
  /// sent; one holding nothing is neither.
  @Test func hiddenButValuedIsSentAndHiddenEmptyIsNot() throws {
    let draft = DiveFormValues(
      diveNumber: 12, startTime: DiveStart.now(), submergedTime: "45", notes: "Turtle")
    var visibility = DiveFormVisibility(hiddenKeys: ["notes", "weight"])
    visibility.reveal(holdingValuesIn: draft)
    #expect(visibility.isVisible(.notes))
    #expect(!visibility.isVisible(.weight))
    let create = try visibility.applied(to: draft).toCreate()
    #expect(create.notes == "Turtle")
    #expect(create.weight == nil)
  }

  /// The boat's name is offered on a boat entry, and kept on screen while it holds a name.
  @Test func theBoatNameFollowsTheEntry() {
    let visibility = DiveFormVisibility(hiddenKeys: [])
    #expect(!visibility.shows(.boatName, in: DiveFormValues()))
    #expect(visibility.shows(.boatName, in: DiveFormValues(entryType: "boat")))
    #expect(visibility.shows(.boatName, in: DiveFormValues(entryType: "shore", boatName: "Legend")))
    #expect(
      !DiveFormVisibility(hiddenKeys: ["boat_name"]).shows(
        .boatName, in: DiveFormValues(entryType: "boat")))
  }

  /// A section renders when one of its fields shows; *Dive info* always; *Tanks* with `mixtures`.
  @Test func sectionsFollowTheirFields() {
    let values = DiveFormValues()
    let basic = DiveFormVisibility(hiddenKeys: [
      "course_uuid", "mixtures", "rating", "tags", "notes",
    ])
    #expect(!DiveFormGroup.training.isShown(basic, values: values))
    #expect(DiveFormGroup.diveInfo.isShown(basic, values: values))
    #expect(!DiveFormGroup.tanks.isShown(basic, values: values))
    #expect(!DiveFormGroup.notes.isShown(basic, values: values))
    #expect(DiveFormGroup.environment.isShown(basic, values: values))
    #expect(!DiveFormGroup.importFiles.isShown(DiveFormVisibility(hiddenKeys: []), values: values))
  }
}
