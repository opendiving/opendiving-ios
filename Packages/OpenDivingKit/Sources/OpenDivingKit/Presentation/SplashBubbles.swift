import Foundation

/// One circle of the launch splash, in the logo's 24-unit box: a stroke ``lineWidth`` wide
/// centred on ``radius``, so a dot opens into a ring.
public struct SplashBubble: Hashable, Sendable {
  public var x: Double
  public var y: Double
  public var radius: Double
  public var lineWidth: Double
  public var opacity: Double
}

/// The web's launch-splash animation: a conveyor of bubbles, each climbing to the next one's
/// place and taking on its size. The top one settles in its slot and fades there while the next
/// rises into it, and a new one grows at the bottom. At every whole step the last three are the
/// logo's circles, smallest filled; the first slot sits on their line, as far below the smallest
/// as 0.6 of the gap above it. One bubble per slot.
public enum SplashBubbles {
  private struct Slot {
    var x: Double
    var y: Double
    var r: Double
    /// The radius left unpainted inside the ring.
    var hole: Double
  }

  private static let slots = [
    Slot(x: 1.84, y: 24.22, r: 0, hole: 0),
    Slot(x: 5.17, y: 20.22, r: 1.78, hole: 0),
    Slot(x: 10.72, y: 13.56, r: 2.89, hole: 1.89),
    Slot(x: 16.83, y: 5.78, r: 3.78, hole: 2.78),
  ]
  private static let top = slots.count - 1
  private static let stroke = 2.0
  /// How far ahead of the top slot, as a share of a step, the top bubble starts to fade.
  private static let fadeLead = 0.75

  /// The seconds a bubble takes to climb one slot.
  public static let step = 0.8

  /// The box the splash centres, in the logo's units: the circles' painted extent, stroke
  /// included, rather than the logo's 24-unit box. The bubble growing in at the bottom draws past
  /// it.
  public static let bounds = (x: 2.14, y: 0.75, width: 19.72, height: 22.5)

  /// The bubbles `elapsed` seconds in. The frame at zero is the logo, still.
  public static func frame(at elapsed: TimeInterval) -> [SplashBubble] {
    slots.indices.map { bubble($0, elapsed: elapsed) }
  }

  private static func bubble(_ i: Int, elapsed: TimeInterval) -> SplashBubble {
    let p = (elapsed / step + Double(i)).truncatingRemainder(dividingBy: Double(slots.count))
    let k = Int(p)
    let f = p - Double(k)
    func at(_ key: KeyPath<Slot, Double>) -> Double {
      hermite(from: k, to: min(k + 1, top), key, f)
    }

    let grow = k == 0 ? ease(f) : 1
    // A step-long fade, started `fadeLead` early while the bubble still rises into its slot —
    // except for the bubble the first frame puts in the top slot: that frame is the whole mark,
    // so this one fades from where it sits, across the first step.
    let lead = i == top && elapsed < step ? 0 : fadeLead
    let fade = 1 - ease(min(1, max(0, p - (Double(top) - lead))))
    let outer = at(\.r) + stroke / 2 * grow
    let hole = max(0, min(at(\.hole), outer - stroke))
    return SplashBubble(
      x: at(\.x), y: at(\.y), radius: (outer + hole) / 2, lineWidth: outer - hole, opacity: fade)
  }

  // Hermite tangents keep position and speed continuous through each slot, so the bubbles glide
  // past the mark rather than ticking between its circles. The top slot's is zero: a bubble
  // comes to rest there instead of overshooting.
  private static func tangent(_ i: Int, _ key: KeyPath<Slot, Double>) -> Double {
    if i == top { return 0 }
    let prev = i == 0 ? 2 * slots[0][keyPath: key] - slots[1][keyPath: key] : slots[i - 1][keyPath: key]
    return (slots[i + 1][keyPath: key] - prev) / 2
  }

  private static func hermite(
    from: Int, to: Int, _ key: KeyPath<Slot, Double>, _ t: Double
  ) -> Double {
    let t2 = t * t
    let t3 = t2 * t
    return (2 * t3 - 3 * t2 + 1) * slots[from][keyPath: key]
      + (t3 - 2 * t2 + t) * tangent(from, key)
      + (3 * t2 - 2 * t3) * slots[to][keyPath: key]
      + (t3 - t2) * tangent(to, key)
  }

  private static func ease(_ t: Double) -> Double {
    t * t * (3 - 2 * t)
  }
}
