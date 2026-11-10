import OpenDivingKit
import SwiftUI

/// The mark of a site held in OpenDiving Commons, as the web draws it: the brand's three bubbles
/// gathered rather than rising, on a 24-unit grid in coral, always beside the word. In teal it
/// marks a site proposed to the Commons.
struct CommonsMark: View {
  @ScaledMetric private var side: CGFloat
  private let color: Color

  init(
    side: CGFloat = 14, relativeTo textStyle: Font.TextStyle = .caption,
    color: Color = .brandCoral
  ) {
    _side = ScaledMetric(wrappedValue: side, relativeTo: textStyle)
    self.color = color
  }

  var body: some View {
    Canvas { context, size in
      let scale = min(size.width, size.height) / 24
      context.translateBy(x: size.width / 2, y: size.height / 2)
      context.scaleBy(x: scale, y: scale)
      let circles = zip(CommonsBubbles.markCentres, CommonsBubbles.markRadii).map {
        Self.circle(x: $0.x, y: $0.y, radius: $1)
      }
      var outlines = Path()
      for circle in circles { outlines.addPath(circle) }
      context.fill(circles[0], with: .color(color))
      context.stroke(outlines, with: .color(color), lineWidth: 2)
    }
    .frame(width: side, height: side)
    .accessibilityHidden(true)
  }

  private static func circle(x: CGFloat, y: CGFloat, radius: CGFloat) -> Path {
    Path(
      ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
  }
}

#Preview {
  HStack(spacing: 16) {
    CommonsMark()
    CommonsMark(side: 64)
    CommonsMark(side: 64, color: .brandTeal)
  }
  .padding()
}
