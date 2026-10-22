import Foundation
import OpenDivingKit
import Testing

struct UnitSystemTests {
  @Test func carriesTheAPIsTwoSpellings() {
    #expect(UnitSystem(rawValue: "metric") == .metric)
    #expect(UnitSystem(rawValue: "imperial") == .imperial)
    #expect(UnitSystem.allCases.count == 2)
  }
}
