import Foundation
import Testing

@testable import OpenDivingKit

/// The line under each tank, golden rows from `opendiving-web/src/lib/dive-mixtures.test.ts`
/// (`gasHintParts`) at `d29d21e4`; and the start's picker round trip.
struct GasHintTests {
  private func parts(_ oxygen: Double?, _ helium: Double?, _ depth: Double?) -> [String] {
    GasMath.hintParts(oxygen: oxygen, helium: helium, depth: depth, ppO2: nil, units: .metric)
  }

  @Test func theGasAndItsMOD() {
    #expect(parts(32, 0, nil) == ["EAN32", "MOD 33.75 m @ ppO₂ 1.4"])
    #expect(parts(54, 0, nil) == ["EAN54", "MOD 15.92 m @ ppO₂ 1.4"])
  }

  @Test func nitroxAddsItsEADOnceADepthIsKnown() {
    #expect(parts(32, 0, 30) == ["EAN32", "MOD 33.75 m @ ppO₂ 1.4", "EAD 24.4 m at 30 m"])
  }

  @Test func aHeliumMixAddsItsENDInstead() {
    let found = parts(21, 35, 45)
    #expect(found.contains("END 25.8 m at 45 m (O₂ narcotic)"))
    #expect(!found.contains { $0.hasPrefix("EAD") })
    #expect(parts(18, 45, 4).contains("END 0.0 m at 4 m (O₂ narcotic)"))
  }

  @Test func airGetsNeither() {
    #expect(parts(21, 0, 30) == ["Air", "MOD 56.66 m @ ppO₂ 1.4"])
    #expect(parts(20.99, 0, 30).count == 2)
    #expect(parts(20.9, 0, 30).count == 2)
  }

  @Test func anUnnameableGasHintsNothingAndAnImpossibleOneOnlyItsName() {
    #expect(parts(nil, 0, 30).isEmpty)
    #expect(parts(32, nil, 30).isEmpty)
    #expect(parts(50, 60, 30) == ["O₂ 50% / He 60%"])
  }

  @Test func aRecordedLimitIsTheOneTheMODNames() {
    #expect(
      GasMath.hintParts(oxygen: 32, helium: 0, depth: nil, ppO2: 1.6, units: .metric)
        == ["EAN32", "MOD 40 m @ ppO₂ 1.6"])
  }

  @Test func theStartsPickerKeepsTheDivesClockAndOffset() throws {
    let start = try #require(DiveTimestamp(wireValue: "2026-10-20T10:04:00+02:00"))
    let (date, zone) = DiveStart.pickerValue(start)
    #expect(zone.secondsFromGMT(for: date) == 7200)
    #expect(DiveStart.picking(date, in: zone, keeping: start) == start)
    let later = date.addingTimeInterval(3600)
    #expect(
      DiveStart.picking(later, in: zone, keeping: start)
        == DiveTimestamp(wireValue: "2026-10-20T11:04:00+02:00"))

    let naive = try #require(DiveTimestamp(wireValue: "2026-10-20T10:04:00"))
    let (naiveDate, utc) = DiveStart.pickerValue(naive)
    #expect(DiveStart.picking(naiveDate, in: utc, keeping: naive) == naive)
    #expect(
      DiveStart.withOffset(-300, naive) == DiveTimestamp(wireValue: "2026-10-20T10:04:00-05:00"))
    #expect(DiveStart.withOffset(nil, start) == DiveTimestamp(wireValue: "2026-10-20T10:04:00"))
  }
}
