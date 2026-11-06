import Testing

@testable import OpenDivingKit

struct ProfileTimeWindowTests {
  private let hour = 3_600_000

  private func window(_ start: Int, _ end: Int, duration: Int) -> ProfileTimeWindow {
    let span = end - start
    let anchor = Double(start) / Double(duration - span)
    return ProfileTimeWindow(duration: duration)
      .scaled(by: Double(duration) / Double(span), from: anchor, to: anchor, duration: duration)
  }

  @Test func theInstantUnderThePinchStaysThere() {
    // A quarter of the way across, zoomed 2×: the instant stays a quarter across.
    let zoomed = ProfileTimeWindow(duration: 1_000_000)
      .scaled(by: 2, from: 0.25, to: 0.25, duration: 1_000_000)
    #expect(zoomed.start == 125_000)
    #expect(zoomed.end == 625_000)
  }

  @Test func theInstantFollowsFingersThatSlideAsTheyPinch() {
    // Half-way across at the start; the fingers' midpoint ends a quarter across.
    let zoomed = ProfileTimeWindow(duration: 1_000_000)
      .scaled(by: 2, from: 0.5, to: 0.25, duration: 1_000_000)
    #expect(zoomed.start == 375_000)
    #expect(zoomed.end == 875_000)
  }

  @Test func zoomsNoCloserThanAMinute() {
    let zoomed = ProfileTimeWindow(duration: hour)
      .scaled(by: 10_000, from: 0.5, to: 0.5, duration: hour)
    #expect(zoomed.span == ProfileTimeWindow.minimumSpan)
    #expect(zoomed.isZoomed(duration: hour))
  }

  @Test func zoomsNoFurtherOutThanTheWholeDive() {
    let zoomed = window(800_000, 900_000, duration: 1_000_000)
    #expect(
      zoomed.scaled(by: 0.01, from: 0, to: 0, duration: 1_000_000)
        == ProfileTimeWindow(duration: 1_000_000))
  }

  @Test func zoomingOutAtTheEndOfTheDiveStaysOnIt() {
    let zoomed = window(800_000, 1_000_000, duration: 1_000_000)
      .scaled(by: 0.5, from: 1, to: 1, duration: 1_000_000)
    #expect(zoomed.start == 600_000)
    #expect(zoomed.end == 1_000_000)
  }

  @Test(arguments: [0, 0.25, 0.3, 0.5, 0.7, 1])
  func aPinchInAndBackOutEndsOnTheWholeDive(anchor: Double) {
    let duration = 2_781_000
    let whole = ProfileTimeWindow(duration: duration)
    let zoomed = whole.scaled(by: 1.7, from: anchor, to: anchor, duration: duration)
    #expect(zoomed.isZoomed(duration: duration))
    #expect(
      zoomed.scaled(by: 1 / 1.7, from: anchor, to: anchor, duration: duration) == whole)
  }

  @Test func aDiveShorterThanAMinuteDoesNotZoom() {
    let whole = ProfileTimeWindow(duration: 50_000)
    let zoomed = whole.scaled(by: 4, from: 0.5, to: 0.5, duration: 50_000)
    #expect(zoomed == whole)
    #expect(!zoomed.isZoomed(duration: 50_000))
  }

  @Test func anEmptyAxisStaysEmpty() {
    let whole = ProfileTimeWindow(duration: 0)
    #expect(whole.scaled(by: 2, from: 0.5, to: 0.5, duration: 0) == whole)
  }

  @Test(arguments: [0, -1, Double.infinity, Double.nan])
  func aFactorThatIsNoScaleLeavesTheWindowAlone(factor: Double) {
    let zoomed = window(100_000, 300_000, duration: 1_000_000)
    #expect(zoomed.scaled(by: factor, from: 0.5, to: 0.5, duration: 1_000_000) == zoomed)
  }

  @Test func aSlideMovesTheWindowAndKeepsItsSpan() {
    let moved = window(100_000, 300_000, duration: 1_000_000)
      .scaled(by: 1, from: 0.5, to: 0.25, duration: 1_000_000)
    #expect(moved.start == 150_000)
    #expect(moved.end == 350_000)
  }

  @Test func aSlideStopsAtEitherEnd() {
    let early = window(100_000, 300_000, duration: 1_000_000)
      .scaled(by: 1, from: 0, to: 1, duration: 1_000_000)
    #expect(early.start == 0)
    #expect(early.end == 200_000)
    let late = window(700_000, 900_000, duration: 1_000_000)
      .scaled(by: 1, from: 1, to: 0, duration: 1_000_000)
    #expect(late.start == 800_000)
    #expect(late.end == 1_000_000)
  }

  @Test func theWholeDiveIsNotZoomed() {
    #expect(!ProfileTimeWindow(duration: hour).isZoomed(duration: hour))
  }
}
