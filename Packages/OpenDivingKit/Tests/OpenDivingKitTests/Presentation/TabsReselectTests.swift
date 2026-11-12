import Testing

@testable import OpenDivingKit

struct TabsReselectTests {
  private func reselect(at offset: Double, upTo max: Double = 2000) -> TabsReselect {
    TabsReselect(offset: offset, range: 0...max, tabsAtBar: 400)
  }

  @Test func fromTheHeadItScrollsDownToTheTabs() {
    #expect(reselect(at: 0) == .tabs(offset: 400))
    #expect(reselect(at: 399) == .tabs(offset: 400))
  }

  @Test func fromDeepInASectionItScrollsBackToTheTabs() {
    #expect(reselect(at: 1500) == .tabs(offset: 400))
  }

  @Test func withTheTabsAtTheBarItScrollsToTheHead() {
    #expect(reselect(at: 400) == .head)
    #expect(reselect(at: 400.5) == .head)
  }

  @Test func aPageTooShortToBringTheTabsUpGoesAsFarAsItScrolls() {
    #expect(reselect(at: 0, upTo: 250) == .tabs(offset: 250))
    #expect(reselect(at: 250, upTo: 250) == .head)
  }
}
