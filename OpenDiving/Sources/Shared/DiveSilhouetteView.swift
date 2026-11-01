import SwiftUI

/// A dive's depth curve as a shape to recognise rather than a chart to read, as the web draws
/// it on a dive card: the curve in the text's colour over a fill fading down from it into
/// whatever is behind. Each value is a fraction of the deepest point; the surface is pinned at
/// both ends, where every dive starts and finishes.
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
      guard !depths.isEmpty else { return path }
      path.move(to: CGPoint(x: rect.minX, y: rect.minY))
      for (index, depth) in depths.enumerated() {
        let x = (CGFloat(index) + 0.5) / CGFloat(depths.count)
        let y = CGFloat(min(max(depth, 0), 1))
        path.addLine(
          to: CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height))
      }
      path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
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
