import Testing

@testable import OpenDivingKit

/// The web's `lib/gear-vessel.test.ts` at its pin, row for row.
struct VesselFactsTests {
  private func parts(
    _ volume: Double?, _ pressure: Double?, _ material: String?, _ units: UnitSystem
  ) -> [String] {
    VesselFacts.parts(volume: volume, workingPressure: pressure, material: material, units: units)
  }

  @Test func aNamedPresetLeadsWithItsNameInBothSystems() {
    #expect(parts(11.1, 207, "aluminium", .metric) == ["AL80", "11.1 L", "207 bar", "Aluminium"])
    #expect(
      parts(11.1, 207, "aluminium", .imperial) == ["AL80", "11.1 L", "3002 psi", "Aluminium"])
  }

  @Test func thePresetIsNamedFromTheBarItsPsiStampStores() {
    let stamped = Measure.pressure.fromDisplay(3000, .imperial)
    #expect(
      parts(11.1, stamped, "aluminium", .imperial) == ["AL80", "11.1 L", "3000 psi", "Aluminium"])
  }

  @Test func anUnnamedVesselInMetric() {
    #expect(parts(12, 232, "steel", .metric) == ["12 L", "232 bar", "Steel"])
  }

  @Test func anUnnamedVesselLeadsWithItsCubicFeetUnderImperial() {
    #expect(parts(12, 232, "steel", .imperial) == ["97 cu ft", "12 L", "3365 psi", "Steel"])
  }

  @Test func noPresetUnlessAllThreeFactsAgree() {
    #expect(parts(11.1, 207, "steel", .imperial).first == "80 cu ft")
    #expect(parts(11.1, 232, "aluminium", .imperial).first?.hasSuffix("cu ft") == true)
    #expect(parts(11.1, 207, nil, .metric) == ["11.1 L", "207 bar"])
  }

  @Test func theHP117IsToldFromTheLP95() {
    #expect(parts(15, 237.3, "steel", .metric).first == "HP117")
    #expect(parts(15, 182, "steel", .metric).first == "LP95")
    #expect(parts(15, 182, "aluminium", .metric).first == "15 L")
  }

  @Test func everyNamedPresetIsNamedFromItsOwnFacts() {
    let named = VolumePresets.groups.flatMap(\.presets).filter { $0.imperialName != nil }
    #expect(named.count == 16)
    for preset in named {
      for units in UnitSystem.allCases {
        #expect(
          parts(preset.liters, preset.workingPressure, preset.material, units).first
            == preset.imperialName)
      }
    }
  }

  @Test func noCubicFeetWithoutBothVolumeAndPressure() {
    #expect(parts(11.1, nil, nil, .imperial) == ["11.1 L"])
    #expect(parts(nil, 207, nil, .imperial).count == 1)
  }

  @Test func nothingRecordedSaysNothing() {
    #expect(parts(nil, nil, nil, .metric).isEmpty)
  }

  @Test func anUnknownMaterialIsShownDeSnaked() {
    #expect(parts(nil, nil, "titanium", .metric) == ["Titanium"])
  }
}
