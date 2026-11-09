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
}
