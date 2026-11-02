import Foundation

/// The dive-computer icon's three bars while a download runs: each rises from its foot in turn,
/// the three hold, then fade out together, and the loop starts over empty.
public enum DiveComputerBars {
  public struct Bar: Hashable, Sendable {
    /// The share of the bar drawn, from its foot.
    public var length: Double
    public var opacity: Double
  }

  /// The seconds between one bar starting to rise and the next.
  private static let stagger = 0.35
  private static let rise = 0.25
  private static let hold = 0.6
  private static let fade = 0.3
  private static let rest = 0.3

  /// The seconds one loop takes.
  public static let loop = stagger * 2 + rise + hold + fade + rest

  /// The three bars whole, as the icon draws them still.
  public static let still = Array(repeating: Bar(length: 1, opacity: 1), count: 3)

  /// The bars, left to right, `elapsed` seconds in.
  public static func frame(at elapsed: TimeInterval) -> [Bar] {
    let t = elapsed.truncatingRemainder(dividingBy: loop)
    let fadeStart = stagger * 2 + rise + hold
    let opacity = 1 - min(1, max(0, (t - fadeStart) / fade))
    return (0..<3).map { i in
      let length = min(1, max(0, (t - Double(i) * stagger) / rise))
      return Bar(length: ease(length), opacity: length > 0 ? opacity : 0)
    }
  }

  private static func ease(_ x: Double) -> Double { x * x * (3 - 2 * x) }
}
