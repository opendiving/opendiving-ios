import SwiftUI

/// The mark of a site held in OpenDiving Commons, as the web draws it: the brand's three bubbles
/// gathered rather than rising, on a 24-unit grid in coral, always beside the word. In teal it
/// marks a site proposed to the Commons; in the foreground style, a button's icon.
struct CommonsMark: View {
  @ScaledMetric private var side: CGFloat
  private let style: AnyShapeStyle

  init(
    side: CGFloat = 14, relativeTo textStyle: Font.TextStyle = .caption,
    color: some ShapeStyle = Color.brandCoral
  ) {
    _side = ScaledMetric(wrappedValue: side, relativeTo: textStyle)
    style = AnyShapeStyle(color)
  }

  var body: some View {
    Canvas { context, size in
      let scale = min(size.width, size.height) / 24
      context.translateBy(x: (size.width - 24 * scale) / 2, y: (size.height - 24 * scale) / 2)
      context.scaleBy(x: scale, y: scale)
      let small = Self.circle(x: 7.11, y: 15.13, radius: 2.81)
      var outlines = small
      outlines.addPath(Self.circle(x: 16.33, y: 17.63, radius: 3.37))
      outlines.addPath(Self.circle(x: 13.58, y: 7.12, radius: 4.12))
      context.fill(small, with: .style(style))
      context.stroke(outlines, with: .style(style), lineWidth: 2)
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
    CommonsMark(side: 64, color: Color.brandTeal)
  }
  .padding()
}
