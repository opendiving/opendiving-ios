import SwiftUI

/// The logo's three bubbles, smallest filled, circling a shared centre in the foreground style, on
/// a 24-unit grid. Still under Reduce Motion.
struct BubbleSpinner: View {
  let side: CGFloat
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var start = Date.now

  private static let radii: [CGFloat] = [1.78, 2.89, 3.78]
  private static let orbit: CGFloat = 6.8
  private static let stroke: CGFloat = 2
  /// The seconds of one turn.
  private static let period = 1.4

  var body: some View {
    TimelineView(.animation(paused: reduceMotion)) { timeline in
      let elapsed = reduceMotion ? 0 : timeline.date.timeIntervalSince(start)
      Canvas { context, size in
        context.translateBy(x: size.width / 2, y: size.height / 2)
        context.scaleBy(x: size.width / 24, y: size.height / 24)
        context.rotate(by: .radians(elapsed / Self.period * 2 * .pi))
        for (index, radius) in Self.radii.enumerated() {
          let angle = Double(index) * 2 * .pi / 3
          let bubble = Path(
            ellipseIn: CGRect(
              x: Self.orbit * cos(angle) - radius, y: Self.orbit * sin(angle) - radius,
              width: radius * 2, height: radius * 2))
          if index == 0 { context.fill(bubble, with: .foreground) }
          context.stroke(bubble, with: .foreground, lineWidth: Self.stroke)
        }
      }
    }
    .frame(width: side, height: side)
  }
}

#Preview {
  BubbleSpinner(side: 24)
    .foregroundStyle(.white)
    .padding()
    .background(Color.brandCoral)
}
