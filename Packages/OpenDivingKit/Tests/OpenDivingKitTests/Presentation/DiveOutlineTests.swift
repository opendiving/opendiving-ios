import Testing

@testable import OpenDivingKit

struct DiveOutlineTests {
  @Test func eachDepthSitsInTheMiddleOfItsSliceBetweenTwoSurfaces() {
    #expect(
      DiveOutline.vertices([0.5, 1]) == [
        .init(x: 0, y: 0), .init(x: 0.25, y: 0.5), .init(x: 0.75, y: 1), .init(x: 1, y: 0),
      ])
    #expect(DiveOutline.vertices([]).isEmpty)
  }

  @Test func theShallowestBetweenTwoPointsCountsTheLineBetweenItsCorners() throws {
    // Corners at 0.1, 0.3, 0.5, 0.7, 0.9: deep either side of a stop at the middle.
    let depths = [0.8, 1, 0.4, 1, 0.8]
    #expect(DiveOutline.shallowest(depths, from: 0.45, to: 0.55) == 0.4)
    let between = try #require(DiveOutline.shallowest(depths, from: 0.35, to: 0.4))
    #expect(abs(between - 0.7) < 1e-9)
  }

  @Test func aDiveThatSurfacedMidwayReachesTheSurfaceThere() {
    #expect(DiveOutline.shallowest([1, 1, 0, 1, 1], from: 0.48, to: 0.52) == 0)
  }

  @Test func theEndsAreTheSurfaceAndNoDepthsAreNoLine() {
    #expect(DiveOutline.shallowest([1, 1], from: 0, to: 0.01) == 0)
    #expect(DiveOutline.shallowest([], from: 0.4, to: 0.6) == nil)
  }
}
