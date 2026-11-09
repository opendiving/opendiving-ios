import Testing

@testable import OpenDivingKit

/// The finder's panel takes three heights and lets go at the one a drag was heading for.
struct SiteFinderPanelTests {
  private let panel = SiteFinderPanel(available: 700)

  @Test func itsHeights() {
    #expect(panel.height(.collapsed) == SiteFinderPanel.collapsedHeight)
    #expect(panel.height(.half) == 350)
    #expect(panel.height(.full) == 700 - SiteFinderPanel.topClearance)
  }

  @Test func aScreenTooShortForThreeStillOrdersThem() {
    let short = SiteFinderPanel(available: 100)
    #expect(short.height(.collapsed) <= short.height(.half))
    #expect(short.height(.half) <= short.height(.full))
  }

  @Test func aDragIsHeldBetweenTheLowestAndTheHighest() {
    #expect(panel.height(.half, dragged: -1000) == panel.height(.collapsed))
    #expect(panel.height(.half, dragged: 1000) == panel.height(.full))
    #expect(panel.height(.half, dragged: 20) == 370)
  }

  @Test func aSlowDragLetsGoAtTheNearest() {
    #expect(panel.settle(from: .half, predicted: 40) == .half)
    #expect(panel.settle(from: .half, predicted: 200) == .full)
    #expect(panel.settle(from: .half, predicted: -200) == .collapsed)
  }

  @Test func aFlickCarriesPastTheNearest() {
    #expect(panel.settle(from: .collapsed, predicted: 700) == .full)
    #expect(panel.settle(from: .full, predicted: -400) == .half)
  }
}
