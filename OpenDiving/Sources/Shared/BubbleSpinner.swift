import OpenDivingKit
import SwiftUI

/// The app's spinner: the logo's three bubbles, smallest filled, in ``CrossingBubbles``' motion.
/// Grey like the system's unless given a `style`, and sized by `controlSize` unless given a
/// `side`. Each frame is computed from the time, so no state of a List row can leave it stopped,
/// as one can leave a `ProgressView`. Still under Reduce Motion.
struct BubbleSpinner: View {
  private let side: CGFloat?
  private let style: AnyShapeStyle
  @Environment(\.controlSize) private var controlSize
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var start = Date.now

  init(side: CGFloat? = nil, style: some ShapeStyle = .secondary) {
    self.side = side
    self.style = AnyShapeStyle(style)
  }

  private var resolvedSide: CGFloat {
    if let side { return side }
    switch controlSize {
    case .mini: return 12
    case .small: return 16
    case .large: return 28
    case .extraLarge: return 36
    default: return 20
    }
  }

  var body: some View {
    TimelineView(.animation(paused: reduceMotion)) { timeline in
      let elapsed = reduceMotion ? 0 : timeline.date.timeIntervalSince(start)
      Canvas { context, size in
        context.translateBy(x: size.width / 2, y: size.height / 2)
        context.scaleBy(x: size.width / 24, y: size.height / 24)
        let centres = CrossingBubbles.centres(at: elapsed)
        for (index, radius) in CrossingBubbles.radii.enumerated() {
          let bubble = Path(
            ellipseIn: CGRect(
              x: centres[index].x - radius, y: centres[index].y - radius,
              width: radius * 2, height: radius * 2))
          if index == 0 { context.fill(bubble, with: .style(style)) }
          context.stroke(bubble, with: .style(style), lineWidth: CrossingBubbles.stroke)
        }
      }
    }
    .frame(width: resolvedSide, height: resolvedSide)
    .accessibilityElement()
    .accessibilityLabel("In progress")
  }
}

#Preview {
  VStack(spacing: 24) {
    HStack(spacing: 24) {
      BubbleSpinner().controlSize(.small)
      BubbleSpinner()
      BubbleSpinner().controlSize(.large)
      BubbleSpinner(side: 96)
    }
    BubbleSpinner(side: 24, style: .white)
      .padding()
      .background(Color.brandCoral, in: Capsule())
  }
  .padding()
}
