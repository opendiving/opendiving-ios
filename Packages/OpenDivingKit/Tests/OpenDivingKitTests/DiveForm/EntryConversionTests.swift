import OpenDivingKit
import Testing

/// Entry's golden rows: `src/lib/units.test.ts`, `src/lib/decimal-entry.test.ts` and
/// `src/lib/entry-units.ts` at `opendiving-web` `d5b2d545`, each row with the line it came from.
struct EntryConversionTests {
  struct Committed: Sendable, CustomTestStringConvertible {
    let source: String
    let measure: Measure
    let typed: Double
    let units: UnitSystem
    let metric: Double

    var testDescription: String { "units.test.ts:\(source)" }
  }

  static let committed: [Committed] = [
    Committed(source: "309", measure: .depth, typed: 100, units: .imperial, metric: 30.48),
    Committed(source: "310", measure: .temperature, typed: 75, units: .imperial, metric: 23.89),
    Committed(source: "311", measure: .pressure, typed: 3000, units: .imperial, metric: 206.84),
    Committed(source: "312", measure: .visibility, typed: 33, units: .imperial, metric: 10),
    Committed(source: "313", measure: .altitude, typed: 1220, units: .imperial, metric: 372),
    Committed(
      source: "320", measure: .temperature, typed: 23.888888888888889, units: .metric,
      metric: 23.89),
    Committed(source: "323", measure: .depth, typed: 30.52, units: .metric, metric: 30.52),
    Committed(source: "327", measure: .visibility, typed: 15.4, units: .metric, metric: 15),
    Committed(source: "328", measure: .altitude, typed: 372.6, units: .metric, metric: 373),
    Committed(source: "336", measure: .visibility, typed: 50, units: .imperial, metric: 15),
  ]

  @Test(arguments: committed) func commitsTheWebsMetricValue(_ row: Committed) {
    #expect(row.measure.fromDisplay(row.typed, row.units) == row.metric)
  }

  @Test func everyEntryDimensionPassesMetricThrough() {
    #expect(
      Measure.entryDimensions == [.depth, .temperature, .weight, .pressure, .visibility, .altitude])
    for measure in Measure.entryDimensions {
      #expect(measure.fromDisplay(1, .metric) == 1)
    }
  }

  /// units.test.ts:278-305: every whole imperial value in each dimension's plausible range
  /// shows again as what was typed.
  @Test(arguments: [
    (Measure.depth, 0, 500, 1), (.temperature, -58, 122, 1), (.weight, 0, 100, 1),
    (.pressure, 0, 5000, 10),
  ])
  func wholeImperialEntryRoundTrips(_ measure: Measure, _ from: Int, _ to: Int, _ step: Int) {
    let broken = stride(from: from, through: to, by: step).filter { typed in
      let metric = measure.fromDisplay(Double(typed), .imperial)
      return UnitFormat.number(metric, measure, .imperial) != String(typed)
    }
    #expect(broken.isEmpty)
  }

  @Test func theLostFootOfVisibilityAndTheAltitudeThatSurvives() {
    #expect(
      UnitFormat.visibility(Measure.visibility.fromDisplay(50, .imperial), .imperial) == "49 ft")
    #expect(
      UnitFormat.altitude(Measure.altitude.fromDisplay(1220, .imperial), .imperial) == "1220 ft")
  }

  /// units.test.ts:353-378.
  @Test func boundsRoundInward() {
    #expect(Measure.altitude.displayBound(-450, .imperial, isMinimum: true) == -1476)
    #expect(Measure.altitude.displayBound(6500, .imperial, isMinimum: false) == 21325)
    #expect(Measure.temperature.displayBound(-50, .imperial, isMinimum: true) == -58)
    #expect(Measure.temperature.displayBound(50, .imperial, isMinimum: false) == 122)
    #expect(Measure.altitude.displayBound(-450, .metric, isMinimum: true) == -450)
    #expect(Measure.depth.displayBound(0.5, .metric, isMinimum: true) == 0.5)
    #expect(Measure.altitude.fromDisplay(-1476, .imperial) >= -450)
    #expect(Measure.altitude.fromDisplay(21325, .imperial) <= 6500)
  }

  /// decimal-entry.test.ts:6-25, with the phone's own reason for the rule: the decimal keypad
  /// types a comma in much of Europe.
  @Test(arguments: [
    ("1.5", 1.5), ("1,5", 1.5), ("30", 30), (" 12,25 ", 12.25), (".5", 0.5), (",5", 0.5),
    ("1.", 1), ("1,", 1), ("-3,5", -3.5), ("12,5", 12.5), ("12.5", 12.5),
  ])
  func readsEitherSeparator(_ text: String, _ value: Double) {
    #expect(DecimalEntry.parse(text) == value)
  }

  @Test(arguments: ["", "abc", "1.2.3", "1,2,3", "1.234,5", "1,234.5", "-", "1e3"])
  func refusesWhatIsNotOneNumber(_ text: String) {
    #expect(DecimalEntry.parse(text) == nil)
  }

  /// decimal-entry.test.ts:30-44.
  @Test func entryMessages() {
    #expect(DecimalEntry.message("  ", min: 0, max: 100) == nil)
    #expect(DecimalEntry.message("1,2,3", min: 0, max: 100) == "Enter a number.")
    #expect(DecimalEntry.message("-1", min: 0, max: 100) == "Enter 0 or more.")
    #expect(DecimalEntry.message("100,5", min: 0, max: 100) == "Enter 100 or less.")
    #expect(DecimalEntry.message("0", min: 0, max: 100) == nil)
    #expect(DecimalEntry.message("100", min: 0, max: 100) == nil)
  }

  /// entry-units.ts `toggleDimension`: flipping to the account's own system removes the
  /// override, so a later change of the account's units carries the dimension with it.
  @Test func entryUnitsOverrideOnlyWhereTheyDiffer() {
    var units = EntryUnits()
    #expect(units.units(.pressure, account: .metric) == .metric)
    units.toggle(.pressure, account: .metric)
    #expect(units.units(.pressure, account: .metric) == .imperial)
    #expect(units.units(.depth, account: .metric) == .metric)
    #expect(units.overrides == ["pressure": .imperial])
    units.toggle(.pressure, account: .metric)
    #expect(units.overrides.isEmpty)
    units.toggle(.sac, account: .metric)
    #expect(units.overrides.isEmpty)
  }
}
