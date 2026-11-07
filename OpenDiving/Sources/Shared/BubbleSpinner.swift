import OpenDivingKit
import SwiftUI

/// The brand's loading animation, the logo's bubbles rising, drawn in the foreground style. Still,
/// as the logo, under Reduce Motion. `width` spans the logo's painted extent; the height follows.
struct BubbleSpinner: View {
  let width: CGFloat
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var start = Date.now

  var body: some View {
    let bounds = SplashBubbles.bounds
    let scale = width / bounds.width
    // Room for the bubble growing in below the box, which the canvas would otherwise clip.
    let overflow = 4 * scale
    Color.clear
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
  BubbleSpinner(width: 20)
    .foregroundStyle(.white)
    .padding()
    .background(Color.brandCoral)
}
