import OpenDivingKit
import Testing

/// The dive form's rules against the web's: each row is a case `src/lib/validations/dive.test.ts`
/// pins at `opendiving-web` `d5b2d545`, with its line, and the sentence `dive.ts` at the same
/// sha gives the field — the test itself often checks only that the entry is refused. Rules a
/// typed value cannot break (a fractional rating, an unparseable date) have no row.
struct DiveFormValidationTests {
  struct Row {
    let source: String
    let change: (inout DiveFormValues) -> Void
    var purpose: DiveFormPurpose = .create
    /// Nil: the values pass.
    let issue: FormIssue?
  }

  /// `validDive` at :28-35.
  static var valid: DiveFormValues {
    DiveFormValues(
      diveNumber: 1, startTime: DiveTimestamp(wireValue: "2024-06-01T09:05:03+02:00"),
      submergedTime: "45:30")
  }

  static func field(_ field: String, _ message: String) -> FormIssue {
    FormIssue(field: field, message: message)
  }

  static func tank(_ member: String, _ message: String) -> FormIssue {
    FormIssue(field: "mixtures", index: 0, member: member, message: message)
  }

  static func sighting(_ member: String, _ message: String) -> FormIssue {
    FormIssue(field: "sightings", index: 0, member: member, message: message)
  }

  static let emptyCylinder =
    "A cylinder can't start a dive empty — enter the fill pressure, or leave this blank if it wasn't recorded."

  static var rows: [Row] {
    [
      Row(source: "40", change: { _ in }, issue: nil),
      Row(
        source: "44", change: { $0.startTime = DiveTimestamp(wireValue: "2024-06-01T09:05:03Z") },
        issue: nil),
      Row(
        source: "52",
        change: { $0.startTime = DiveTimestamp(wireValue: "2024-06-01T09:05:03+05:45") }, issue: nil
      ),
      Row(
        source: "60", change: { $0.startTime = DiveTimestamp(wireValue: "2024-06-01T09:05:03") },
        issue: field(
          "start_time", "Start time must include a UTC offset, e.g. 2021-04-04T10:04:47+02:00")),
      Row(
        source: "68", change: { $0.startTime = nil },
        issue: field("start_time", "Start time is required")),
      Row(
        source: "90", change: { $0.startTime = DiveTimestamp(wireValue: "2026-04-17T11:49:23") },
        purpose: .edit, issue: nil),
      Row(
        source: "126", change: { $0.startTime = DiveTimestamp(wireValue: "2002-06-18") },
        purpose: .edit, issue: nil),
      Row(
        source: "130", change: { $0.startTime = DiveTimestamp(wireValue: "2002-06-18") },
        issue: field(
          "start_time", "Start time must include a UTC offset, e.g. 2021-04-04T10:04:47+02:00")),
      Row(source: "145", change: { $0.submergedTime = "5:00" }, issue: nil),
      Row(source: "149", change: { $0.submergedTime = "120:00" }, issue: nil),
      Row(
        source: "155", change: { $0.submergedTime = "10:60" },
        issue: field("submerged_time", "Dive time must be minutes or MM:SS, e.g. 45 or 67:30")),
      Row(source: "164", change: { $0.submergedTime = "45" }, issue: nil),
      Row(source: "168", change: { $0.submergedTime = "7" }, issue: nil),
      Row(source: "172", change: { $0.submergedTime = "120" }, issue: nil),
      Row(
        source: "180", change: { $0.submergedTime = "1030" },
        issue: field("submerged_time", "Dive time must be minutes or MM:SS, e.g. 45 or 67:30")),
      Row(
        source: "188", change: { $0.submergedTime = "45:" },
        issue: field("submerged_time", "Dive time must be minutes or MM:SS, e.g. 45 or 67:30")),
      Row(
        source: "196", change: { $0.submergedTime = "abc" },
        issue: field("submerged_time", "Dive time must be minutes or MM:SS, e.g. 45 or 67:30")),
      Row(
        source: "207", change: { $0.submergedTime = "" },
        issue: field("submerged_time", "Dive time is required")),
      Row(
        source: "217", change: { $0.diveNumber = 0 },
        issue: field("dive_number", "Dive number must be a positive integer")),
      Row(source: "236", change: { $0.diveNumber = 2_147_483_647 }, issue: nil),
      Row(
        source: "237", change: { $0.diveNumber = 2_147_483_648 },
        issue: field("dive_number", "Dive number must be at most 2,147,483,647")),
      Row(source: "236", change: { $0.visibility = 2_147_483_647 }, issue: nil),
      Row(
        source: "237", change: { $0.visibility = 2_147_483_648 },
        issue: field("visibility", "That's more than a visibility can hold")),
      Row(
        source: "226", change: { $0.maxDepth = -1 },
        issue: field("max_depth", "Max depth must be positive")),
      Row(source: "252", change: { $0.bottomTemperature = -1 }, issue: nil),
      Row(
        source: "260", change: { $0.weight = -1 },
        issue: field("weight", "Weight must be zero or positive")),
      Row(source: "267", change: { $0.weight = 0 }, issue: nil),
      Row(source: "272", change: { $0.weight = 4.5 }, issue: nil),
      Row(
        source: "356", change: { $0.rating = 0 },
        issue: field("rating", "Rating must be between 1 and 5")),
      Row(
        source: "362", change: { $0.rating = 6 },
        issue: field("rating", "Rating must be between 1 and 5")),
      Row(source: "349", change: { $0.rating = 5 }, issue: nil),
      Row(source: "378", change: { $0.boatName = "" }, issue: nil),
      Row(
        source: "384", change: { $0.boatName = String(repeating: "x", count: 256) },
        issue: field("boat_name", "Boat name cannot exceed 255 characters")),
      Row(source: "391", change: { $0.tags = [String(repeating: "🐋", count: 64)] }, issue: nil),
      Row(
        source: "401", change: { $0.tags = ["night", String(repeating: "x", count: 65)] },
        issue: field("tags", "A tag can be at most 64 characters")),
      Row(source: "427", change: { $0.altitude = 372 }, issue: nil),
      Row(source: "433", change: { $0.altitude = -450 }, issue: nil),
      Row(source: "433", change: { $0.altitude = 6500 }, issue: nil),
      Row(
        source: "441", change: { $0.altitude = -451 },
        issue: field("altitude", "Altitude must be between -450 and 6500 m (-1,476 and 21,325 ft)")),
      Row(
        source: "457", change: { $0.altitude = 9000 },
        issue: field("altitude", "Altitude must be between -450 and 6500 m (-1,476 and 21,325 ft)")),
      // diveMixtureSchema, over `validMixture` at :476-480.
      Row(source: "483", change: { $0.tanks = [Self.mixture] }, issue: nil),
      Row(source: "496", change: { $0.tanks = [TankValues(oxygen: 21, helium: 0)] }, issue: nil),
      Row(source: "519", change: { $0.tanks = [TankValues()] }, issue: nil),
      Row(source: "527", change: { $0.tanks = [TankValues(volume: 12, oxygen: 50)] }, issue: nil),
      Row(
        source: "540", change: { $0.tanks = [TankValues(volume: 12, oxygen: 50, helium: 60)] },
        issue: tank("helium", "Oxygen and helium together cannot exceed 100%")),
      Row(
        source: "560", change: { $0.tanks = [Self.mixture(startPressure: 0)] },
        issue: tank("start_pressure", emptyCylinder)),
      Row(
        source: "566", change: { $0.tanks = [Self.mixture(startPressure: -1)] },
        issue: tank("start_pressure", emptyCylinder)),
      Row(
        source: "572", change: { $0.tanks = [Self.mixture(startPressure: 351)] },
        issue: tank(
          "start_pressure",
          "Start pressure must be at most 350 bar (5,076 psi) — check the units on that reading.")),
      Row(source: "580", change: { $0.tanks = [Self.mixture(startPressure: 0.1)] }, issue: nil),
      Row(source: "580", change: { $0.tanks = [Self.mixture(startPressure: 350)] }, issue: nil),
      Row(
        source: "592", change: { $0.tanks = [Self.mixture(endPressure: 3000)] },
        issue: tank(
          "end_pressure",
          "End pressure must be at most 350 bar (5,076 psi) — check the units on that reading.")),
      Row(
        source: "603", change: { $0.tanks = [Self.mixture(startPressure: 200, endPressure: 0)] },
        issue: nil),
      Row(
        source: "615", change: { $0.tanks = [TankValues(volume: 12, oxygen: 101, helium: 0)] },
        issue: tank("oxygen", "Oxygen percentage must be at most 100")),
      Row(
        source: "623", change: { $0.tanks = [TankValues(volume: 12, oxygen: 21, helium: -1)] },
        issue: tank("helium", "Helium percentage must be at least 0")),
      Row(
        source: "628", change: { $0.tanks = [TankValues(volume: 0, oxygen: 21, helium: 0)] },
        issue: tank("volume", "Volume must be positive")),
      Row(
        source: "633", change: { $0.tanks = [Self.mixture(startPressure: 50, endPressure: 200)] },
        issue: tank("end_pressure", "End pressure cannot be greater than start pressure")),
      Row(
        source: "642", change: { $0.tanks = [Self.mixture(startPressure: 200, endPressure: 200)] },
        issue: nil),
      Row(source: "660", change: { $0.tanks = [Self.mixture(endPressure: 200)] }, issue: nil),
      Row(
        source: "694", change: { $0.tanks = [TankValues(volume: 12, oxygen: 30, helium: 70)] },
        issue: nil),
      Row(
        source: "703", change: { $0.tanks = [TankValues(volume: 12, oxygen: 18, helium: 45)] },
        issue: nil),
      Row(
        source: "712", change: { $0.tanks = [TankValues(volume: 12, oxygen: 150, helium: 0)] },
        issue: tank("oxygen", "Oxygen percentage must be at most 100")),
      Row(
        source: "dive.ts:283", change: { $0.tanks = [TankValues(po2Limit: 0.3)] },
        issue: tank("po2_limit", "ppO₂ limit must be at least 0.4 bar")),
      Row(
        source: "dive.ts:284", change: { $0.tanks = [TankValues(po2Limit: 2.1)] },
        issue: tank("po2_limit", "ppO₂ limit must be at most 2.0 bar")),
      // sightings.
      Row(source: "1545", change: { $0.sightings = [Self.seen(abundance: "few")] }, issue: nil),
      Row(
        source: "1554", change: { $0.sightings = [Self.seen(count: 3, abundance: "few")] },
        issue: sighting("abundance", "A sighting carries a count or a band, not both")),
      Row(source: "1571", change: { $0.sightings = [Self.seen(count: 2_147_483_647)] }, issue: nil),
      Row(
        source: "1578", change: { $0.sightings = [Self.seen(count: 0)] },
        issue: sighting("count", "A count is at least 1 — leave it blank if you didn't count")),
      Row(
        source: "1578", change: { $0.sightings = [Self.seen(count: 2_147_483_648)] },
        issue: sighting("count", "That's more than a count can hold")),
      Row(
        source: "1590",
        change: { $0.sightings = [Self.seen(notes: String(repeating: "x", count: 100_001))] },
        issue: sighting("notes", "Notes cannot exceed 100,000 characters")),
    ]
  }

  static var mixture: TankValues { TankValues(volume: 12, oxygen: 21, helium: 0) }

  static func mixture(startPressure: Double? = nil, endPressure: Double? = nil) -> TankValues {
    TankValues(
      volume: 12, startPressure: startPressure, endPressure: endPressure, oxygen: 21, helium: 0)
  }

  static func seen(count: Int? = nil, abundance: String? = nil, notes: String = "") -> SightingWrite
  {
    SightingWrite(
      speciesUuid: .init(uuidString: "01a30000-0000-7000-8000-0000000000c1")!, count: count,
      abundance: abundance, notes: notes)
  }

  @Test func eachRowIsTheWebsVerdict() {
    for row in Self.rows {
      var values = Self.valid
      row.change(&values)
      let issues = values.issues(for: row.purpose)
      if let expected = row.issue {
        #expect(issues == [expected], "dive.test.ts:\(row.source)")
      } else {
        #expect(issues.isEmpty, "dive.test.ts:\(row.source)")
      }
    }
  }

  /// :711-741: an out-of-range fraction draws its own sentence and not the sum's.
  @Test func anOutOfRangeFractionIsLeftToItsOwnRule() {
    var values = Self.valid
    values.tanks = [TankValues(volume: 12, oxygen: 21, helium: -1)]
    #expect(values.issues(for: .create).map(\.member) == ["helium"])
  }

  /// A blank number box on a new dive shows the web's sentence, which is zod's own; an edit
  /// sends no number at all.
  @Test func aBlankNumber() {
    var values = Self.valid
    values.diveNumber = nil
    #expect(
      values.issues(for: .create) == [
        Self.field("dive_number", "Invalid input: expected number, received undefined")
      ])
    #expect(values.issues(for: .edit).isEmpty)
  }

  /// The API's own rule, which the web leaves to the server: a dive queued offline would learn
  /// of it only when sent.
  @Test func anAverageDeeperThanTheMaximum() {
    var values = Self.valid
    values.maxDepth = 18
    values.avgDepth = 20
    #expect(
      values.issues(for: .create) == [
        Self.field("avg_depth", "Average depth cannot be greater than max depth.")
      ])
  }

  @Test func oneSentencePerFieldTheFirst() {
    var values = Self.valid
    values.tanks = [Self.mixture(startPressure: 0, endPressure: 400)]
    let invalid = FormInvalid(issues: values.issues(for: .create))
    #expect(
      invalid.message(for: "mixtures", index: 0, member: "start_pressure") == Self.emptyCylinder)
    #expect(
      invalid.message(for: "mixtures", index: 0, member: "end_pressure")
        == "End pressure must be at most 350 bar (5,076 psi) — check the units on that reading.")
    #expect(invalid.issues.count == 2)
  }
}
