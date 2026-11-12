import Foundation
import Observation

/// Where the site finder's panel is and how it is moving. The detent it rests at, which the list
/// lays out for, changes only once a move lands; while a finger or a spring moves it, only what
/// rides on the panel's edge reads the move, so neither the first pull nor the letting go lays the
/// list out again. The map makes room for ``target`` from the moment a spring sets off.
@MainActor
@Observable
public final class SiteFinderPanelDrag {
  /// The detent the panel rests at, or last rested at while it moves.
  public private(set) var detent: SiteFinderPanel.Detent
  /// How far a finger has pulled the panel up from ``detent``.
  public private(set) var dragged = 0.0
  /// The detent a spring is carrying the panel to, which it rests at once the move lands.
  public private(set) var heading: SiteFinderPanel.Detent?
  /// While a finger or the spring after it moves the panel, which is then laid out at its tallest
  /// so that the move lays nothing out again. At rest it takes its detent's height, and holds
  /// nothing below the screen for VoiceOver to reach.
  public private(set) var isMoving = false
  @ObservationIgnored private var moves = 0

  public init(detent: SiteFinderPanel.Detent = .half) {
    self.detent = detent
  }

  /// A finger has pulled the panel `dragged` points up. Caught on its way to a detent, it is
  /// pulled from that one.
  public func follow(_ dragged: Double) {
    _ = begin()
    if let heading {
      detent = heading
      self.heading = nil
    }
    self.dragged = dragged
  }

  /// Starts a move, outside the animation that carries it, and returns the number that ends it.
  public func begin() -> Int {
    moves += 1
    if !isMoving { isMoving = true }
    return moves
  }

  /// Sends the panel to `target`: inside the animation that carries it there.
  public func head(to target: SiteFinderPanel.Detent) {
    heading = target
    dragged = 0
  }

  /// The move numbered `move` has landed, which rests the panel where it was heading unless
  /// another move has begun since.
  public func end(_ move: Int) {
    guard move == moves else { return }
    if let heading {
      detent = heading
      self.heading = nil
    }
    if isMoving { isMoving = false }
  }

  /// Where the panel is heading, or rests: what a step from the handle steps from.
  public var target: SiteFinderPanel.Detent { heading ?? detent }

  /// How tall the panel stands in `panel`, where it is on its way.
  public func height(in panel: SiteFinderPanel) -> Double {
    if let heading { return panel.height(heading) }
    return panel.height(detent, dragged: dragged)
  }

  /// Where the panel goes as the opened site changes from `old` to `new`, nil for where it is: a
  /// site opens up from where the list left it, or down off the top where a match was opened
  /// from, and closed, the list comes back where the panel opens. A site opened in place of
  /// another leaves the panel be.
  public func detent(openingSite new: UUID?, after old: UUID?) -> SiteFinderPanel.Detent? {
    new == nil || old == nil || target == .collapsed ? .half : nil
  }

  /// How far the panel can still grow before it stands at its tallest: what a swipe up on its
  /// content moves the panel by before the content scrolls.
  public func roomAbove(in panel: SiteFinderPanel) -> Double {
    max(0, panel.height(.full) - height(in: panel))
  }
}
