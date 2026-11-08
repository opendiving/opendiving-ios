import Foundation

/// The crossing bubble spinner's motion, in the logo's 24-unit box centred on the origin, y down.
/// The large bubble slides round the orbit without stopping while the two smaller ones take turns
/// to cross it through the centre; the one not crossing slides back to meet the crosser, and the
/// three are an equilateral triangle each time a crossing ends and the next begins.
public enum CrossingBubbles {
  /// The seconds one crossing takes. The pattern turns once every six.
  public static let crossing: TimeInterval = 0.5

  /// The logo's circles at 0.8, smallest first, so a bubble crossing the centre clears the large
  /// one on the orbit.
  public static let radii: [Double] = [1.424, 2.312, 3.024]
  public static let orbit = 7.85
  public static let stroke = 2.0

  /// Where the crossing bubble sets off at the start, in degrees, which puts the large one 15°
  /// clockwise of the top.
  private static let startAngle = 45.0

  /// The bubbles' centres `elapsed` seconds in, smallest first.
  public static func centres(at elapsed: TimeInterval) -> [SIMD2<Double>] {
    let crossings = max(0, elapsed) / crossing
    let index = crossings.rounded(.down)
    let progress = crossings - index
    let start = (index.truncatingRemainder(dividingBy: 6) * 60 + startAngle) * .pi / 180
    let spread = (120 - 60 * progress) * .pi / 180
    // Keeps the triangle's centre on the orbit's: the crosser is on the orbit at each end.
    let across = -2 * cos(spread) * orbit * direction(start)
    let sliding = orbit * direction(start + spread)
    let large = orbit * direction(start - spread)
    // The crosser arrives where the next crossing starts, so the two swap roles every crossing.
    return index.truncatingRemainder(dividingBy: 2) == 0
      ? [across, sliding, large] : [sliding, across, large]
  }

  private static func direction(_ angle: Double) -> SIMD2<Double> {
    SIMD2(cos(angle), sin(angle))
  }
}
