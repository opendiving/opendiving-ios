import OpenDivingKit
import Testing

/// Transcribed from `src/lib/dive-mixtures.test.ts` at `opendiving-web` `ec014ff9`.
struct GasMathTests {
  private static let air = OxygenFractions(oxygen: 21, helium: 0)
  private static let ean32 = OxygenFractions(oxygen: 32, helium: 0)
  private static let ean54 = OxygenFractions(oxygen: 54, helium: 0)

  /// `:33-96`.
  @Test(
    arguments: [
      (21.0, 0.0, "Air"), (100, 0, "Oxygen"), (32, 0, "EAN32"), (20.9, 0, "Air"),
      (20.99, 0, "Air"), (22, 0, "EAN22"), (21, 35, "21/35"), (18, 45, "18/45"), (10, 70, "10/70"),
      (32.4, 0, "EAN32"), (20.99, 35.01, "21/35"), (99.6, 0, "Oxygen"),
      (50, 60, "O₂ 50% / He 60%"), (0, 0, "O₂ 0% / He 0%"), (-5, 0, "O₂ -5% / He 0%"),
      (30, 70, "30/70"),
    ] as [(Double, Double, String)])
  func gasNames(oxygen: Double, helium: Double, expected: String) {
    #expect(GasMath.name(oxygen: oxygen, helium: helium) == expected)
  }

  @Test func noNameForAnUnrecordedOrNonFiniteFraction() {
    #expect(GasMath.name(oxygen: nil, helium: 0) == nil)
    #expect(GasMath.name(oxygen: 32, helium: nil) == nil)
    #expect(GasMath.name(oxygen: .nan, helium: 0) == nil)
    #expect(GasMath.name(oxygen: 21, helium: .nan) == nil)
  }

  /// `:98-141`.
  @Test func mod() throws {
    #expect(abs(try #require(GasMath.mod(oxygen: 32)) - 33.75) < 1e-5)
    #expect(abs(try #require(GasMath.mod(oxygen: 32, ppO2: GasMath.decoPPO2)) - 40) < 1e-5)
    #expect(abs(try #require(GasMath.mod(oxygen: 21)) - 56.6667) < 1e-3)
    #expect(abs(try #require(GasMath.mod(oxygen: 100, ppO2: GasMath.decoPPO2)) - 6) < 1e-5)
    #expect(GasMath.mod(oxygen: 0) == nil)
    #expect(GasMath.mod(oxygen: -1) == nil)
    #expect(GasMath.mod(oxygen: nil) == nil)
    #expect(GasMath.mod(oxygen: .nan) == nil)
    #expect(GasMath.mod(oxygen: 50, ppO2: 0.4) == nil)
    #expect(GasMath.mod(oxygen: 100, ppO2: 0.4) == nil)
    #expect(abs(try #require(GasMath.mod(oxygen: 40, ppO2: 0.4))) < 1e-5)
  }

  /// `:584-598`.
  @Test func ppO2Limit() {
    #expect(GasMath.ppO2Limit(recorded: 1.6) == 1.6)
    #expect(GasMath.ppO2Limit(recorded: nil) == GasMath.workingPPO2)
    #expect(GasMath.ppO2Limit(recorded: .nan) == GasMath.workingPPO2)
  }

  /// `:239-332`.
  @Test func modWarningInMetric() {
    func warning(_ oxygen: Double?, _ helium: Double, at depth: Double?) -> String? {
      GasMath.modWarning(
        OxygenFractions(oxygen: oxygen, helium: helium), breathedDepth: depth, units: .metric)
    }
    #expect(warning(32, 0, at: 30) == nil)
    #expect(warning(32, 0, at: 33.75) == nil)
    #expect(warning(28, 0, at: 40) == nil)
    #expect(warning(40, 0, at: 25) == nil)
    #expect(warning(100, 0, at: 4) == nil)
    #expect(warning(28, 0, at: 40.01)?.contains("40 m working limit") == true)
    #expect(
      warning(32, 0, at: 33.7512)?.contains("33.75 m is past this mix's 33.75 m working limit")
        == true)
    #expect(
      warning(32, 0, at: 33.8)?.contains("33.8 m is past this mix's 33.75 m working limit") == true)

    let working = warning(32, 0, at: 36)
    #expect(working?.contains("33.75 m working limit") == true)
    #expect(working?.contains("1.4") == true)
    #expect(working?.contains("decompression") == true)

    let deco = warning(32, 0, at: 45)
    #expect(deco?.contains("40 m limit") == true)
    #expect(deco?.contains("1.6") == true)
    #expect(deco?.contains("decompression") == false)
    #expect(working != deco)

    #expect(warning(50, 0, at: 40)?.contains("22 m limit") == true)
    #expect(warning(100, 0, at: nil) == nil)
    #expect(warning(nil, 0, at: 40) == nil)
    #expect(warning(0, 0, at: 40) == nil)
    #expect(warning(18, 45, at: 60) == nil)
  }

  /// `:617-641`.
  @Test func modWarningInImperial() {
    func warning(_ oxygen: Double, at depth: Double) -> String? {
      GasMath.modWarning(
        OxygenFractions(oxygen: oxygen, helium: 0), breathedDepth: depth, units: .imperial)
    }
    #expect(
      warning(28, at: 40.02)?.contains("131.3 ft is past this mix's 131.2 ft working limit") == true
    )
    #expect(
      warning(21, at: 56.67)?.contains("185.9 ft is past this mix's 185.9 ft working limit") == true
    )
    let deco = warning(32, at: 45)
    #expect(deco?.contains("147.6 ft is past this mix's 131.2 ft limit") == true)
    #expect(deco?.contains("ppO₂ 1.6") == true)
  }

  /// The two whole sentences, as `modWarning`'s template writes them.
  @Test func modWarningSentences() {
    #expect(
      GasMath.modWarning(Self.ean32, breathedDepth: 45, units: .metric)
        == "45 m is past this mix's 40 m limit at ppO₂ 1.6.")
    #expect(
      GasMath.modWarning(Self.ean32, breathedDepth: 36, units: .metric)
        == "36 m is past this mix's 33.75 m working limit (ppO₂ 1.4); it is within the 1.6 ceiling used for decompression."
    )
  }

  /// `:425-582`.
  @Test func diveModWarning() {
    func warning(_ cylinders: [OxygenFractions], _ depth: Double?) -> String? {
      GasMath.diveModWarning(cylinders, maxDepth: depth, units: .metric)
    }
    let parallel32 = OxygenFractions(oxygen: 32, helium: 0, usage: "parallel")
    #expect(warning([Self.ean32], 45)?.contains("40 m limit") == true)
    #expect(warning([Self.ean32], 36)?.contains("working limit") == true)
    #expect(warning([Self.ean32], 30) == nil)
    #expect(warning([Self.air, Self.ean54], 45.91) == nil)
    #expect(warning([Self.air, Self.ean54], 80)?.contains("No gas logged for this dive") == true)
    #expect(warning([Self.air, Self.ean54], 80)?.contains("66.19 m") == true)
    #expect(warning([Self.ean54, Self.ean32, Self.air], 80)?.contains("66.19 m") == true)
    #expect(warning([parallel32, parallel32], 45)?.contains("40 m limit") == true)
    #expect(warning([parallel32, parallel32], 36)?.contains("working limit") == true)

    let unflagged = warning([Self.ean32, Self.ean32], 45)
    #expect(unflagged?.contains("No gas logged for this dive") == true)
    #expect(unflagged?.contains("working limit") == false)

    let mixedSpelling = [
      OxygenFractions(oxygen: 32, usage: "parallel"),
      OxygenFractions(oxygen: 32, helium: 0, usage: "parallel"),
    ]
    #expect(warning(mixedSpelling, 45)?.contains("40 m limit") == true)
    let mixedGas = [
      OxygenFractions(oxygen: 21, helium: 0, usage: "parallel"),
      OxygenFractions(oxygen: 54, helium: 0, usage: "parallel"),
    ]
    #expect(warning(mixedGas, 45.91) == nil)
    #expect(warning([parallel32, Self.ean32], 45)?.contains("No gas logged for this dive") == true)
    #expect(warning([Self.air, Self.ean32], 45) == nil)
    #expect(warning([Self.ean54], nil) == nil)
    #expect(warning([Self.air, Self.ean54], nil) == nil)
    #expect(warning([], 40) == nil)
    #expect(warning([], 60) == nil)
    #expect(warning([Self.air], 60)?.contains("working limit") == true)
    #expect(
      warning([Self.air, Self.ean54], GasMath.mod(oxygen: 21, ppO2: GasMath.decoPPO2)) == nil)
    #expect(warning([OxygenFractions(oxygen: nil), OxygenFractions(oxygen: 0)], 40) == nil)
    #expect(warning([Self.air, OxygenFractions(oxygen: nil)], 80)?.contains("66.19 m") == true)
    // `:672-686`: a recorded high limit does not move the threshold.
    #expect(warning([OxygenFractions(oxygen: 50)], 32)?.contains("22 m") == true)
  }

  /// The dive-wide sentence whole.
  @Test func diveModWarningSentence() {
    #expect(
      GasMath.diveModWarning([Self.air, Self.ean54], maxDepth: 80, units: .metric)
        == "No gas logged for this dive can be breathed at 80 m - the deepest-capable of them reaches 66.19 m at ppO₂ 1.6."
    )
  }

  /// `:604-613`: the MOD a tank card prints, in feet, floored at a tenth.
  @Test func modInImperial() {
    #expect(
      UnitFormat.comparableDepth(GasMath.mod(oxygen: 21)!, .imperial, floor: true) == "185.9 ft")
    #expect(
      UnitFormat.comparableDepth(GasMath.mod(oxygen: 32)!, .imperial, floor: true) == "110.7 ft")
  }

  /// `:643-670`: EAN50 at its recorded 1.6 and at the working fallback.
  @Test func modAtTheRecordedLimit() {
    let limit = GasMath.ppO2Limit(recorded: 1.6)
    #expect(
      UnitFormat.comparableDepth(GasMath.mod(oxygen: 50, ppO2: limit)!, .metric, floor: true)
        == "22 m")
    #expect(NumberText.plain(limit) == "1.6")
    let fallback = GasMath.ppO2Limit(recorded: nil)
    #expect(
      UnitFormat.comparableDepth(GasMath.mod(oxygen: 50, ppO2: fallback)!, .metric, floor: true)
        == "18 m")
    #expect(NumberText.plain(fallback) == "1.4")
  }
}
