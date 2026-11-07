import SwiftUI

/// The logo at display size, from the web's circles on their 24-unit grid. The `dive` symbol is the
/// same mark for icon sizes, and its curves show when it is drawn large.
struct BrandMark: View {
  @ScaledMetric private var side: CGFloat

  init(side: CGFloat, relativeTo textStyle: Font.TextStyle = .title) {
    _side = ScaledMetric(wrappedValue: side, relativeTo: textStyle)
  }

  var body: some View {
    Canvas { context, size in
      context.scaleBy(x: size.width / 24, y: size.height / 24)
      let small = Self.circle(x: 5.17, y: 20.22, radius: 1.78)
      var outlines = small
      outlines.addPath(Self.circle(x: 10.72, y: 13.56, radius: 2.89))
      outlines.addPath(Self.circle(x: 16.83, y: 5.78, radius: 3.78))
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
  BrandMark(side: 72)
    .padding()
}
