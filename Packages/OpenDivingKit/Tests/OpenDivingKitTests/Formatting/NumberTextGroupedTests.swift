import OpenDivingKit
import Testing

/// What `toLocaleString()` prints under `en-US`.
struct NumberTextGroupedTests {
  @Test(arguments: [
    (0, "0"), (999, "999"), (1000, "1,000"), (3600, "3,600"), (123_456, "123,456"),
    (1_234_567, "1,234,567"), (-999, "-999"), (-1200, "-1,200"),
    (Int.min, "-9,223,372,036,854,775,808"),
  ])
  func groupsThousands(_ n: Int, _ expected: String) {
    #expect(NumberText.grouped(n) == expected)
  }
}
