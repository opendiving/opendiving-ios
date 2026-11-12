import OpenDivingKit
import SwiftUI

/// A dive's depth curve as a shape to recognise rather than a chart to read, as the web draws
/// it on a dive card: the curve in the text's colour over a fill fading down from it into
/// whatever is behind, along ``DiveOutline``.
struct DiveSilhouetteView: View {
  let depths: [Double]

  var body: some View {
    ZStack {
      Silhouette(depths: depths, closed: true)
        .fill(
          LinearGradient(
            colors: [Color.primary.opacity(0.45), Color.primary.opacity(0)], startPoint: .top,
            endPoint: .bottom))
      Silhouette(depths: depths, closed: false)
        .stroke(Color.primary, style: StrokeStyle(lineWidth: 1, lineJoin: .round))
    }
    .accessibilityHidden(true)
  }

  /// The curve, or the curve closed along the box's foot.
  private nonisolated struct Silhouette: Shape {
    let depths: [Double]
    let closed: Bool

    func path(in rect: CGRect) -> Path {
      var path = Path()
      let pieces = DiveOutline.segments(depths)
      guard let first = pieces.first else { return path }
      func point(_ vertex: DiveOutline.Vertex) -> CGPoint {
        CGPoint(x: rect.minX + vertex.x * rect.width, y: rect.minY + vertex.y * rect.height)
      }
      path.move(to: point(first.start))
      for piece in pieces {
        path.addCurve(
          to: point(piece.end), control1: point(piece.control1), control2: point(piece.control2))
      }
      if closed {
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
      }
      return path
    }
  }
}

#Preview {
  DiveSilhouetteView(depths: [0, 0.4, 0.9, 1, 0.7, 0.5, 0.15, 0.15, 0])
    .frame(height: 56)
    .padding()
    .background(Color(red: 68 / 255, green: 108 / 255, blue: 107 / 255))
}
