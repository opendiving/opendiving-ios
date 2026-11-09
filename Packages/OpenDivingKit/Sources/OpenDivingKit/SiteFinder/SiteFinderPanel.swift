import Foundation

/// The site finder's panel over its map: the search box alone, half the screen, or the screen
/// up to just under the top bar. It opens half way.
public struct SiteFinderPanel: Hashable, Sendable {
  public enum Detent: CaseIterable, Hashable, Sendable {
    case collapsed, half, full
  }

  /// The search box and the handle over it.
  public static let collapsedHeight = 77.0
  /// The strip of map the panel at its tallest leaves under the top bar.
  public static let topClearance = 8.0

  /// The height the panel may take: the screen's below the top bar and above the tab bar.
  public var available: Double

  public init(available: Double) {
    self.available = available
  }

  public func height(_ detent: Detent) -> Double {
    let full = max(Self.collapsedHeight, available - Self.topClearance)
    switch detent {
    case .collapsed: return Self.collapsedHeight
    case .half: return min(full, max(Self.collapsedHeight, available / 2))
    case .full: return full
    }
  }

  /// The height `detent` takes dragged up by `translation` points, held between the lowest and
  /// the highest it goes.
  public func height(_ detent: Detent, dragged translation: Double) -> Double {
    min(height(.full), max(height(.collapsed), height(detent) + translation))
  }

  /// Where a drag from `detent` lets go: the detent nearest where the drag was heading, the
  /// gesture's predicted end translation, measured upwards, so a flick carries past the nearest.
  public func settle(from detent: Detent, predicted: Double) -> Detent {
    let target = height(detent, dragged: predicted)
    return Detent.allCases.min { abs(height($0) - target) < abs(height($1) - target) } ?? detent
  }

  /// Where a drag on the panel lets go, and how fast it carries on into the detent.
  public struct Release: Hashable, Sendable {
    public let detent: Detent
    /// The finger's speed as a share of the way left to the detent each second, upwards: the
    /// initial velocity a spring takes.
    public let velocity: Double
  }

  /// How far a point a second carries once let go, as a scroll view decelerates at its normal
  /// rate of 0.998 a millisecond.
  static let flickReach = 0.998 / (1 - 0.998) / 1000
  /// The fastest ``Release/velocity``, under the stiffness of the spring the panel settles on, so
  /// a flick let go just short of a detent does not throw the panel past it.
  public static let maxReleaseVelocity = 10.0

  /// A drag from `detent` let go `dragged` points up while moving up at `velocity` points a
  /// second.
  public func release(from detent: Detent, dragged: Double, velocity: Double) -> Release {
    let target = settle(from: detent, predicted: dragged + velocity * Self.flickReach)
    let left = height(target) - height(detent, dragged: dragged)
    let share = abs(left) < 1 ? 0 : velocity / left
    let limit = Self.maxReleaseVelocity
    return Release(detent: target, velocity: min(limit, max(-limit, share)))
  }

  /// How far above the half the panel opens to the controls riding on its edge fade out over.
  public static let controlsFade = 64.0

  /// How much shows of the controls riding on the panel's edge when it is `shown` points tall:
  /// all of them up to the half it opens to, none ``controlsFade`` above it, where they would
  /// crowd the strip of map the panel leaves.
  public func controlsOpacity(shown: Double) -> Double {
    min(1, max(0, (height(.half) + Self.controlsFade - shown) / Self.controlsFade))
  }
}
