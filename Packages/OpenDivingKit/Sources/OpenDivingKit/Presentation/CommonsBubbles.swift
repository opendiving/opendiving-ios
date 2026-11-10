import Foundation

/// The Commons mark turning into the crossing spinner and back, in the logo's 24-unit box
/// centred on the origin, y down: each bubble slides and resizes between its place in the mark
/// and its place in ``CrossingBubbles``' motion, so neither end jumps.
public enum CommonsBubbles {
  /// The mark's circles, smallest first, as `CommonsMark` draws them less 12 a side.
  public static let markCentres: [SIMD2<Double>] = [
    SIMD2(-4.89, 3.13), SIMD2(4.33, 5.63), SIMD2(1.58, -4.88),
  ]
  public static let markRadii: [Double] = [2.81, 3.37, 4.12]

  /// The seconds the mark takes to become the spinner, or the spinner the mark.
  public static let morph: TimeInterval = 0.3

  /// The bubbles' centres and radii, smallest first: the mark at `blend` 0, the spinner
  /// `elapsed` seconds into its motion at 1, eased between.
  public static func frame(elapsed: TimeInterval, blend: Double) -> [(SIMD2<Double>, Double)] {
    let t = max(0, min(1, blend))
    let eased = t * t * (3 - 2 * t)
    let spinning = CrossingBubbles.centres(at: elapsed)
    return markCentres.indices.map { i in
      let centre = markCentres[i] + (spinning[i] - markCentres[i]) * eased
      let radius = markRadii[i] + (CrossingBubbles.radii[i] - markRadii[i]) * eased
      return (centre, radius)
    }
  }

  /// Where the blend stands `since` seconds after it stood at `from`, heading for the spinner
  /// while `loading` and back to the mark otherwise.
  public static func blend(from: Double, loading: Bool, since: TimeInterval) -> Double {
    let step = max(0, since) / morph
    return loading ? min(1, from + step) : max(0, from - step)
  }
}
