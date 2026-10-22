import SwiftUI

/// A dive's depth over time, filled from the surface down to the curve. Each value is a
/// fraction of the deepest point, evenly spaced across the width.
nonisolated struct DepthOutlineShape: Shape {
  let depths: [Double]

  func path(in rect: CGRect) -> Path {
    var path = Path()
    guard depths.count > 1 else { return path }
    let step = rect.width / CGFloat(depths.count - 1)
    path.move(to: CGPoint(x: rect.minX, y: rect.minY))
    for (index, depth) in depths.enumerated() {
      let clamped = CGFloat(min(max(depth, 0), 1))
      path.addLine(
        to: CGPoint(x: rect.minX + step * CGFloat(index), y: rect.minY + clamped * rect.height))
    }
    path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
    path.closeSubpath()
    return path
  }
}
