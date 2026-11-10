import Observation

/// Where the site finder's panel is and how it is moving. The detent it rests at, which the finder
/// lays out for, changes only once a move lands; while a finger or a spring moves it, only what
/// rides on the panel's edge reads the move, so neither the first pull nor the letting go draws
/// the finder, its list and its map again.
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
}
