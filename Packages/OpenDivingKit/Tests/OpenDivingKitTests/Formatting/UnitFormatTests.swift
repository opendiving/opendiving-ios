import OpenDivingKit
import Testing

/// The golden table: every row is a case the web's own `src/lib/units.test.ts` pins at
/// `opendiving-web` `ec014ff9`, transcribed with the line it came from rather than worked
/// out from the constants here, which would restate this code and prove nothing.
struct UnitFormatTests {
  struct Row: Sendable, CustomTestStringConvertible {
    let source: String
    let measure: Measure
    let metric: Double
    let units: UnitSystem
    var decimals: Int? = nil
    let expected: String

    var testDescription: String { "units.test.ts:\(source)" }
  }

  static let golden: [Row] = [
    Row(source: "67", measure: .depth, metric: 30.52, units: .metric, expected: "30.52 m"),
    Row(source: "68", measure: .pressure, metric: 206.84, units: .metric, expected: "206.84 bar"),
    Row(source: "69", measure: .weight, metric: 6.5, units: .metric, expected: "6.5 kg"),
    Row(source: "75", measure: .depth, metric: 18.288, units: .metric, expected: "18.29 m"),
    Row(
      source: "76", measure: .depth, metric: 28.000000000000004, units: .metric, expected: "28 m"),
    Row(source: "80", measure: .depth, metric: 30.5, units: .metric, expected: "30.5 m"),
    Row(source: "81", measure: .depth, metric: 30, units: .metric, expected: "30 m"),
    Row(source: "87", measure: .temperature, metric: 23.89, units: .metric, expected: "23.89°C"),
    Row(source: "88", measure: .visibility, metric: 15, units: .metric, expected: "15 m"),
    Row(source: "93", measure: .altitude, metric: 372, units: .metric, expected: "372 m"),
    Row(source: "97", measure: .sac, metric: 0.82, units: .metric, expected: "0.82 bar/min"),
    Row(source: "98", measure: .rmv, metric: 18.24, units: .metric, expected: "18.24 L/min"),
    Row(source: "99", measure: .gasVolume, metric: 3618, units: .metric, expected: "3618 L"),
    Row(source: "105", measure: .depth, metric: 30.48, units: .imperial, expected: "100 ft"),
    Row(source: "106", measure: .temperature, metric: 23.89, units: .imperial, expected: "75°F"),
    Row(source: "107", measure: .weight, metric: 6, units: .imperial, expected: "13 lb"),
    Row(source: "108", measure: .pressure, metric: 206.84, units: .imperial, expected: "3000 psi"),
    Row(source: "109", measure: .visibility, metric: 15, units: .imperial, expected: "49 ft"),
    Row(source: "110", measure: .altitude, metric: 372, units: .imperial, expected: "1220 ft"),
    Row(source: "116", measure: .sac, metric: 0.82, units: .imperial, expected: "11.9 psi/min"),
    Row(source: "117", measure: .rmv, metric: 18.24, units: .imperial, expected: "0.64 cuft/min"),
    Row(source: "118", measure: .gasVolume, metric: 3618, units: .imperial, expected: "127.8 cuft"),
    Row(source: "122", measure: .temperature, metric: 0, units: .imperial, expected: "32°F"),
    Row(source: "123", measure: .temperature, metric: -50, units: .imperial, expected: "-58°F"),
    Row(source: "127", measure: .altitude, metric: -430, units: .imperial, expected: "-1411 ft"),
    Row(
      source: "135", measure: .depth, metric: 30.52, units: .metric, decimals: 0, expected: "31 m"),
    Row(
      source: "136", measure: .depth, metric: 30, units: .metric, decimals: 1, expected: "30.0 m"),
    Row(
      source: "137", measure: .rmv, metric: 18.24, units: .metric, decimals: 1,
      expected: "18.2 L/min"),
    Row(
      source: "143", measure: .depth, metric: 30.48, units: .imperial, decimals: 1,
      expected: "100 ft"),
    Row(
      source: "144", measure: .rmv, metric: 18.24, units: .imperial, decimals: 1,
      expected: "0.64 cuft/min"),
    Row(source: "335", measure: .visibility, metric: 15, units: .imperial, expected: "49 ft"),
    Row(source: "342", measure: .altitude, metric: 372, units: .imperial, expected: "1220 ft"),
  ]

  @Test(arguments: golden)
  func formatsAsTheWebDoes(row: Row) {
    #expect(
      UnitFormat.format(row.metric, row.measure, row.units, decimals: row.decimals)
        == row.expected)
  }

  struct ComparableRow: Sendable, CustomTestStringConvertible {
    let source: String
    let meters: Double
    let units: UnitSystem
    let floor: Bool
    let expected: String

    var testDescription: String { "units.test.ts:\(source)" }
  }

  static let comparable: [ComparableRow] = [
    ComparableRow(source: "150", meters: 33.75, units: .metric, floor: false, expected: "33.75 m"),
    ComparableRow(source: "151", meters: 40, units: .metric, floor: false, expected: "40 m"),
    ComparableRow(
      source: "157", meters: 40.02, units: .imperial, floor: false, expected: "131.3 ft"),
    ComparableRow(source: "158", meters: 40, units: .imperial, floor: false, expected: "131.2 ft"),
    ComparableRow(
      source: "162", meters: 15.925925925925927, units: .metric, floor: false, expected: "15.93 m"),
    ComparableRow(
      source: "164", meters: 15.925925925925927, units: .metric, floor: true, expected: "15.92 m"),
    ComparableRow(
      source: "172", meters: 39.999999999999993, units: .metric, floor: true, expected: "40 m"),
    ComparableRow(source: "179", meters: 9.2, units: .metric, floor: true, expected: "9.2 m"),
    ComparableRow(
      source: "181", meters: 18.49002849002849, units: .metric, floor: true, expected: "18.49 m"),
    ComparableRow(
      source: "189", meters: 39.46996466431094, units: .metric, floor: true, expected: "39.46 m"),
  ]

  @Test(arguments: comparable)
  func comparableDepthAsTheWebWritesIt(row: ComparableRow) {
    #expect(UnitFormat.comparableDepth(row.meters, row.units, floor: row.floor) == row.expected)
  }

  /// `units.test.ts:42-46`: the exact definitions.
  @Test func theConstantsAreTheExactDefinitions() {
    #expect(UnitFormat.metersPerFoot == 0.3048)
    #expect(UnitFormat.kgPerPound == 0.45359237)
    #expect(abs(UnitFormat.litersPerCubicFoot - 0.3048 * 0.3048 * 0.3048 * 1000) < 1e-9)
    #expect(UnitFormat.feetPerMile == 5280)
    #expect(abs(UnitFormat.psiPerBar - 14.503773773020923) < 1e-12)
  }

  /// `units.test.ts:53-60`.
  @Test func roundsToTheRequestedPlaces() {
    #expect(NumberText.round(23.888888888888889, decimals: 2) == 23.89)
    #expect(NumberText.round(29.8704, decimals: 2) == 29.87)
    #expect(NumberText.round(372.4, decimals: 0) == 372)
    #expect(NumberText.round(28.000000000000004, decimals: 2) == 28)
  }

  /// `units.test.ts:196-213`.
  @Test func labelsAndWords() {
    #expect(Measure.depth.label(.metric) == "m")
    #expect(Measure.depth.label(.imperial) == "ft")
    #expect(Measure.temperature.label(.imperial) == "°F")
    #expect(Measure.pressure.label(.imperial) == "psi")
    #expect(Measure.weight.label(.imperial) == "lb")
    #expect(Measure.rmv.label(.imperial) == "cuft/min")
    #expect(Measure.sac.label(.imperial) == "psi/min")
    #expect(Measure.depth.word(.imperial) == "feet")
    #expect(Measure.temperature.word(.imperial) == "degrees Fahrenheit")
    #expect(Measure.temperature.word(.metric) == "degrees Celsius")
    #expect(Measure.pressure.word(.imperial) == "psi")
    #expect(Measure.rmv.word(.imperial) == "cubic feet per minute")
    #expect(Measure.rmv.word(.metric) == "liters per minute")
  }

  /// `units.test.ts:219-227`.
  @Test func convertsForDisplayOnly() {
    #expect(Measure.depth.toDisplay(30.48, .metric) == 30.48)
    #expect(UnitFormat.number(30.52, .depth, .metric) == "30.52")
    #expect(abs(Measure.depth.toDisplay(30.48, .imperial) - 100) < 1e-10)
    #expect(Measure.temperature.toDisplay(0, .imperial) == 32)
    #expect(abs(Measure.pressure.toDisplay(1, .imperial) - 14.5038) < 1e-4)
  }
}
