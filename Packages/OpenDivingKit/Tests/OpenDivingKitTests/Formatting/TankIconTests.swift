import OpenDivingKit
import Testing

/// Transcribed from `tankGas` in `src/lib/dive-mixtures.ts` and `MixtureTankIcon` at
/// `opendiving-web` `2edb6d51`.
struct TankIconTests {
  @Test(
    arguments: [
      (21.0, 0.0, TankIcon.Gas.air), (20.5, 0, .air), (21.4, 0, .air), (32, 0, .nitrox),
      (18, 0, .nitrox), (99.5, 0, .oxygen), (100, 0, .oxygen), (21, 35, .trimix),
      (50, 60, .air), (0, 0, .air),
    ] as [(Double, Double, TankIcon.Gas)])
  func gas(oxygen: Double, helium: Double, expected: TankIcon.Gas) {
    #expect(TankIcon(volume: 12, oxygen: oxygen, helium: helium, left: false).gas == expected)
  }

  @Test func anUnrecordedFractionDrawsAsAir() {
    #expect(TankIcon(volume: 12, oxygen: 32, helium: nil, left: false).gas == .air)
    #expect(TankIcon(volume: 12, oxygen: nil, helium: 0, left: false).gas == .air)
  }

  @Test func aTwinSetIsATwinSetPresetsLitres() {
    #expect(TankIcon(volume: 24, oxygen: 21, helium: 0, left: false).kind == .twin)
    #expect(TankIcon(volume: 22.2, oxygen: 21, helium: 0, left: false).kind == .twin)
    #expect(TankIcon(volume: 12, oxygen: 21, helium: 0, left: false).kind == .single)
    #expect(TankIcon(volume: nil, oxygen: 21, helium: 0, left: false).kind == .single)
  }

  @Test func theLeftOfAParallelPairWinsOverATwinSetsLitres() {
    #expect(TankIcon(volume: 24, oxygen: 21, helium: 0, left: true).kind == .left)
  }
}
