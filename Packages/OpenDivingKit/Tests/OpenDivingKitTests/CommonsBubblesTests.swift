import Foundation
import Testing

@testable import OpenDivingKit

struct CommonsBubblesTests {
  @Test func theEndsAreTheMarkAndTheSpinner() {
    let mark = CommonsBubbles.frame(elapsed: 1.3, blend: 0)
    #expect(mark.map(\.0) == CommonsBubbles.markCentres)
    #expect(mark.map(\.1) == CommonsBubbles.markRadii)
    let spinner = CommonsBubbles.frame(elapsed: 1.3, blend: 1)
    let centres = CrossingBubbles.centres(at: 1.3)
    for i in 0..<3 {
      #expect(((spinner[i].0 - centres[i]) * (spinner[i].0 - centres[i])).sum() < 1e-18)
      #expect(abs(spinner[i].1 - CrossingBubbles.radii[i]) < 1e-12)
    }
  }

  @Test func halfwayEachBubbleIsBetweenItsTwoSizes() {
    let frame = CommonsBubbles.frame(elapsed: 0, blend: 0.5)
    for i in 0..<3 {
      #expect(frame[i].1 < CommonsBubbles.markRadii[i])
      #expect(frame[i].1 > CrossingBubbles.radii[i])
    }
  }

  @Test func theBlendRampsEachWayAndTurnsBackFromWhereItIs() {
    let half = CommonsBubbles.morph / 2
    #expect(CommonsBubbles.blend(from: 0, loading: true, since: half) == 0.5)
    #expect(CommonsBubbles.blend(from: 0, loading: true, since: 10) == 1)
    #expect(CommonsBubbles.blend(from: 0.5, loading: false, since: half) == 0)
    #expect(CommonsBubbles.blend(from: 1, loading: false, since: 10) == 0)
  }
}
