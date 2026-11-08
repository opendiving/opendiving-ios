import Foundation
import Testing

@testable import OpenDivingKit

struct CrossingBubblesTests {
  private static let step = 1.0 / 240
  /// Two full turns of the pattern, sampled finely.
  private static let times = (0...Int(12 * CrossingBubbles.crossing / step)).map {
    Double($0) * step
  }

  private func length(_ v: SIMD2<Double>) -> Double { (v * v).sum().squareRoot() }

  @Test func theLargeBubbleNeverLeavesTheOrbit() {
    for t in Self.times {
      #expect(abs(length(CrossingBubbles.centres(at: t)[2]) - CrossingBubbles.orbit) < 1e-9)
    }
  }

  @Test func theSmallerBubblesTakeTurnsCrossingTheCentre() {
    let half = CrossingBubbles.crossing / 2
    #expect(length(CrossingBubbles.centres(at: half)[0]) < 1e-9)
    #expect(length(CrossingBubbles.centres(at: 3 * half)[1]) < 1e-9)
    #expect(length(CrossingBubbles.centres(at: 5 * half)[0]) < 1e-9)
  }

  @Test func noBubbleJumps() {
    var last = CrossingBubbles.centres(at: 0)
    for t in Self.times.dropFirst() {
      let now = CrossingBubbles.centres(at: t)
      for i in now.indices { #expect(length(now[i] - last[i]) < 0.25) }
      last = now
    }
  }

  @Test func theBubblesNeverTouchAndStayInTheBox() {
    let painted = CrossingBubbles.radii.map { $0 + CrossingBubbles.stroke / 2 }
    for t in Self.times {
      let centres = CrossingBubbles.centres(at: t)
      for i in centres.indices {
        #expect(length(centres[i]) + painted[i] <= 12)
        for j in centres.indices where j > i {
          #expect(length(centres[i] - centres[j]) > painted[i] + painted[j])
        }
      }
    }
  }

  @Test func itComesBackToTheStartAfterSixCrossings() {
    let start = CrossingBubbles.centres(at: 0)
    let back = CrossingBubbles.centres(at: 6 * CrossingBubbles.crossing)
    for i in start.indices { #expect(length(start[i] - back[i]) < 1e-9) }
  }
}
