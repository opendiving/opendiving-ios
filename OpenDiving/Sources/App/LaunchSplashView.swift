import OpenDivingKit
import SwiftUI

/// The web's launch splash without its wordmark: white bubbles rising over coral, sized and placed
/// by the web's numbers. Still, as the logo, under Reduce Motion.
struct LaunchSplashView: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var start = Date.now

  var body: some View {
    GeometryReader { proxy in
      // The width of 26 of the logo's units: the web's `min(22vmin, 160px)`.
      let mark = min(min(proxy.size.width, proxy.size.height) * 0.22, 160)
      bubbles(width: mark * SplashBubbles.bounds.width / 26)
        // Above true centre, which reads as low: the usual optical lift, plus the distance the
        // bubbles' weight drops below their box over a loop.
        .offset(y: -(mark * 0.07 + proxy.size.height * 0.03))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .foregroundStyle(.white)
    .background(Color(.sRGB, red: 1, green: 127 / 255, blue: 80 / 255))
    .ignoresSafeArea()
    .accessibilityElement()
    .accessibilityLabel("Loading OpenDiving")
  }

  private func bubbles(width: CGFloat) -> some View {
    let bounds = SplashBubbles.bounds
    let scale = width / bounds.width
    // Room for the bubble growing in below the box, which the canvas would otherwise clip.
    let overflow = 4 * scale
    return Color.clear
      .frame(width: width, height: bounds.height * scale)
      .overlay {
        TimelineView(.animation(paused: reduceMotion)) { timeline in
          let elapsed = reduceMotion ? 0 : timeline.date.timeIntervalSince(start)
          Canvas { context, _ in
            for bubble in SplashBubbles.frame(at: elapsed) where bubble.radius > 0 {
              let radius = bubble.radius * scale
              let center = CGPoint(
                x: (bubble.x - bounds.x) * scale + overflow,
                y: (bubble.y - bounds.y) * scale + overflow)
              var layer = context
              layer.opacity = bubble.opacity
              layer.stroke(
                Path(
                  ellipseIn: CGRect(
                    x: center.x - radius, y: center.y - radius, width: radius * 2,
                    height: radius * 2)),
                with: .foreground, lineWidth: bubble.lineWidth * scale)
            }
          }
        }
        .padding(-overflow)
      }
  }
}

#Preview {
  LaunchSplashView()
}
