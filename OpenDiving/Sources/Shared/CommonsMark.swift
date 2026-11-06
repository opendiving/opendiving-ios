import SwiftUI

/// The mark of a site held in OpenDiving Commons, as the web draws it: the brand's three bubbles
/// gathered rather than rising, on a 24-unit grid in coral, always beside the word.
struct CommonsMark: View {
  @ScaledMetric private var side: CGFloat

  init(side: CGFloat = 14, relativeTo textStyle: Font.TextStyle = .caption) {
    _side = ScaledMetric(wrappedValue: side, relativeTo: textStyle)
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
      context.fill(small, with: .color(.brandCoral))
      context.stroke(outlines, with: .color(.brandCoral), lineWidth: 2)
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
  }
  .padding()
}
