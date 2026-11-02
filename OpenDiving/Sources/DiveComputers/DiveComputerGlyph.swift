import OpenDivingKit
import SwiftUI

/// The `dive-computer` icon drawn on its 24-unit grid rather than from the asset, so that its
/// three bars can rise and fade while a download runs; still and whole otherwise.
struct DiveComputerGlyph: View {
  let animated: Bool

  /// Each bar's x, its foot and its top.
  private static let bars: [(x: Double, foot: Double, top: Double)] = [
    (8.5, 14.5, 11), (12, 14.5, 9.5), (15.5, 14.5, 12.5),
  ]

  var body: some View {
    if animated {
      TimelineView(.animation) { timeline in
        glyph(DiveComputerBars.frame(at: timeline.date.timeIntervalSinceReferenceDate))
      }
    } else {
      glyph(DiveComputerBars.still)
    }
  }

  private func glyph(_ frame: [DiveComputerBars.Bar]) -> some View {
    Canvas { context, size in
      let scale = min(size.width, size.height) / 24
      context.scaleBy(x: scale, y: scale)
      let style = StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
      let shading = GraphicsContext.Shading.foreground
      context.stroke(Self.body, with: shading, style: style)
      for (bar, state) in zip(Self.bars, frame) where state.opacity > 0 {
        var path = Path()
        path.move(to: CGPoint(x: bar.x, y: bar.foot))
        path.addLine(to: CGPoint(x: bar.x, y: bar.foot - (bar.foot - bar.top) * state.length))
        var layer = context
        layer.opacity = state.opacity
        layer.stroke(path, with: shading, style: style)
      }
    }
  }

  /// The case and its two straps; each strap's rounded corners are quadratic curves through the
  /// corner its two lines meet at.
  private static let body: Path = {
    var path = Path(roundedRect: CGRect(x: 5, y: 6, width: 14, height: 12), cornerRadius: 3.5)
    for (edge, end, corner, flip) in [(6.0, 2.0, 2.0, 1.0), (18.0, 22.0, 22.0, -1.0)] {
      let lean = 1.61 * flip
      path.move(to: CGPoint(x: 15.8, y: edge))
      path.addLine(to: CGPoint(x: 15.32, y: end + lean))
      path.addQuadCurve(to: CGPoint(x: 13.32, y: end), control: CGPoint(x: 15, y: corner))
      path.addLine(to: CGPoint(x: 10.68, y: end))
      path.addQuadCurve(to: CGPoint(x: 8.68, y: end + lean), control: CGPoint(x: 9, y: corner))
      path.addLine(to: CGPoint(x: 8.2, y: edge))
    }
    return path
  }()
}

#Preview {
  HStack(spacing: 24) {
    DiveComputerGlyph(animated: true)
    DiveComputerGlyph(animated: false)
  }
  .frame(height: 96)
  .padding()
}
