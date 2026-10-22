import OpenDivingKit
import Testing

/// JavaScript's own number spellings, each expected value what Node prints for the same
/// expression: these are the primitives every web string is built from.
struct NumberTextTests {
  @Test(
    arguments: [
      (28.0, "28"), (5e-7, "5e-7"), (0.000001, "0.000001"), (1e21, "1e+21"), (-0.0, "0"),
      (0.1 + 0.2, "0.30000000000000004"), (123_456_789_012_345_680_000.0, "123456789012345680000"),
      (-1.5e-10, "-1.5e-10"), (100.0, "100"), (1.2345e-5, "0.000012345"), (30.52, "30.52"),
      (-58.0, "-58"),
    ] as [(Double, String)])
  func plainIsStringOfANumber(value: Double, expected: String) {
    #expect(NumberText.plain(value) == expected)
  }

  @Test(
    arguments: [
      (-0.4, 0, "-0"), (2.5, 0, "3"), (1.005, 2, "1.00"), (36.5, 0, "37"), (0.5, 0, "1"),
      (1.45, 1, "1.4"), (-1.45, 1, "-1.4"), (0.0, 2, "0.00"), (-2.5, 0, "-3"),
      (1234.5678, 2, "1234.57"), (0.000001, 3, "0.000"), (5e-7, 20, "0.00000050000000000000"),
    ] as [(Double, Int, String)])
  func fixedIsToFixed(value: Double, decimals: Int, expected: String) {
    #expect(NumberText.fixed(value, decimals: decimals) == expected)
  }

  @Test(
    arguments: [(-2.5, -2.0), (2.5, 3.0), (-0.5, 0.0), (0.49999999999999994, 0.0), (-3.7, -4.0)]
      as [(Double, Double)])
  func roundIsMathRound(value: Double, expected: Double) {
    #expect(NumberText.round(value) == expected)
  }
}
