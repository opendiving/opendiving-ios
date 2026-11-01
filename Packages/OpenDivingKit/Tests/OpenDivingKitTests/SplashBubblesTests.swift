import OpenDivingKit
import Testing

struct SplashBubblesTests {
  @Test func theFirstFrameIsTheLogo() {
    let bubbles = SplashBubbles.frame(at: 0).filter { $0.radius > 0 }
    // The logo's three circles at its 2-unit stroke, the smallest filled: a filled circle is a
    // stroke as wide as its outer radius, centred halfway out.
    let logo: [(x: Double, y: Double, outer: Double, inner: Double)] = [
      (5.17, 20.22, 1.78 + 1, 0),
      (10.72, 13.56, 2.89 + 1, 2.89 - 1),
      (16.83, 5.78, 3.78 + 1, 3.78 - 1),
    ]
    #expect(bubbles.count == logo.count)
    for (bubble, circle) in zip(bubbles, logo) {
      #expect(abs(bubble.x - circle.x) < 1e-9)
      #expect(abs(bubble.y - circle.y) < 1e-9)
      #expect(abs(bubble.radius + bubble.lineWidth / 2 - circle.outer) < 1e-9)
      #expect(abs(bubble.radius - bubble.lineWidth / 2 - circle.inner) < 1e-9)
      #expect(bubble.opacity == 1)
    }
  }

  @Test func aWholeLoopLaterTheBubblesAreBackInTheirSlots() {
    let loop = SplashBubbles.step * 4
    let start = SplashBubbles.frame(at: loop)
    let later = SplashBubbles.frame(at: loop * 2)
    for (a, b) in zip(start, later) {
      #expect(abs(a.x - b.x) < 1e-9)
      #expect(abs(a.radius - b.radius) < 1e-9)
      #expect(abs(a.opacity - b.opacity) < 1e-9)
    }
  }

}
