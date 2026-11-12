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

  @Test func eachPieceLeavesItsCornersAlongTheirTangents() throws {
    // Flat at the turn, along the secant at the surface.
    let pieces = DiveOutline.segments([1])
    #expect(pieces.count == 2)
    let down = try #require(pieces.first)
    #expect(down.start == .init(x: 0, y: 0))
    #expect(down.end == .init(x: 0.5, y: 1))
    #expect(abs(down.control1.x - 1 / 6) < 1e-9)
    #expect(abs(down.control1.y - 1 / 3) < 1e-9)
    #expect(abs(down.control2.x - 1 / 3) < 1e-9)
    #expect(down.control2.y == 1)
    #expect(DiveOutline.segments([]).isEmpty)
  }

  @Test func theCurveNeverLeavesTheBandBetweenTwoCorners() throws {
    let depths = [0.2, 0.9, 1, 0.3, 0.35, 0.95, 0.1, 0.1]
    let line = DiveOutline.vertices(depths)
    for (start, end) in zip(line, line.dropFirst()) {
      for step in 0...20 {
        let x = start.x + (end.x - start.x) * Double(step) / 20
        let depth = try #require(DiveOutline.shallowest(depths, from: x, to: x))
        #expect(depth >= min(start.y, end.y) - 1e-9)
        #expect(depth <= max(start.y, end.y) + 1e-9)
      }
    }
  }

  @Test func theShallowestReadsTheCurveRatherThanTheStraightLine() throws {
    // A quarter of the way down the first piece of a one-depth dive: the straight line's 0.5, the
    // curve deeper, flattening into the bottom.
    let depth = try #require(DiveOutline.shallowest([1], from: 0.125, to: 0.125))
    #expect(abs(depth - 0.296875) < 1e-9)
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
