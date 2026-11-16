import CoreGraphics

extension CGRect {
  /// The rectangle `share` of the way from this one to `other`, each edge moving in a line.
  func interpolated(to other: CGRect, by share: Double) -> CGRect {
    let mix = { (from: Double, to: Double) in from + (to - from) * share }
    return CGRect(
      x: mix(minX, other.minX), y: mix(minY, other.minY),
      width: mix(width, other.width), height: mix(height, other.height))
  }
}
