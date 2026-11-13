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

/// A drag lets go at a detent with the finger's speed, as a share of the way left to it.
struct SiteFinderPanelReleaseTests {
  private let panel = SiteFinderPanel(available: 700)

  @Test func aDragLetGoStillSettlesAtTheNearest() {
    let release = panel.release(from: .half, dragged: 40, velocity: 0)
    #expect(release == SiteFinderPanel.Release(detent: .half, velocity: 0))
  }

  @Test func aFlickCarriesPastTheNearestAsAScrollViewWould() {
    #expect(panel.release(from: .half, dragged: 40, velocity: 600).detent == .full)
    #expect(panel.release(from: .half, dragged: 40, velocity: 200).detent == .half)
  }

  @Test func theSpeedIsAShareOfTheWayLeft() {
    let release = panel.release(from: .half, dragged: 0, velocity: 1000)
    #expect(release.detent == .full)
    #expect(abs(release.velocity - 1000 / (panel.height(.full) - panel.height(.half))) < 1e-9)
  }

  @Test func aFlickJustShortOfTheTopIsHeldUnderTheLimit() {
    let release = panel.release(from: .half, dragged: 340, velocity: 2000)
    #expect(release == SiteFinderPanel.Release(detent: .full, velocity: 10))
  }

  @Test func aFingerAlreadyAtTheDetentPassesNoSpeed() {
    #expect(panel.release(from: .full, dragged: 50, velocity: 3000).velocity == 0)
  }
}

/// The controls on the panel's edge fade out above the half it opens to.
struct SiteFinderPanelControlsTests {
  private let panel = SiteFinderPanel(available: 700)

  @Test func theyShowUpToTheHalf() {
    #expect(panel.controlsOpacity(shown: panel.height(.collapsed)) == 1)
    #expect(panel.controlsOpacity(shown: panel.height(.half)) == 1)
  }

  @Test func theyFadeOverTheDistanceAboveIt() {
    let half = panel.height(.half)
    #expect(panel.controlsOpacity(shown: half + SiteFinderPanel.controlsFade / 2) == 0.5)
    #expect(panel.controlsOpacity(shown: half + SiteFinderPanel.controlsFade) == 0)
    #expect(panel.controlsOpacity(shown: panel.height(.full)) == 0)
  }
}

/// The panel floats as an island at its lowest, and turns into a sheet as it is pulled up.
struct SiteFinderPanelIslandTests {
  private let panel = SiteFinderPanel(available: 700)

  @Test func itIsAnIslandOnlyNearItsLowest() {
    let lowest = panel.height(.collapsed)
    #expect(panel.islandShare(shown: lowest) == 1)
    #expect(panel.islandShare(shown: lowest + SiteFinderPanel.islandSpan / 2) == 0.5)
    #expect(panel.islandShare(shown: lowest + SiteFinderPanel.islandSpan) == 0)
    #expect(panel.islandShare(shown: panel.height(.half)) == 0)
  }
}
