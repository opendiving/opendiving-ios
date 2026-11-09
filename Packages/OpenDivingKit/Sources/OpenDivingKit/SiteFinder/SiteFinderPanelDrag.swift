import Observation

/// The site finder's panel on the move. How far a finger has pulled it is held apart from the
/// finder so that only what rides on the panel's edge is drawn again as the finger moves, rather
/// than the finder, its list and its map on every frame.
@MainActor
@Observable
public final class SiteFinderPanelDrag {
  /// How far a finger has pulled the panel up from its detent.
  public private(set) var dragged = 0.0
  /// While a finger or the spring after it moves the panel, which is then laid out at its tallest
  /// so that the move lays nothing out again. At rest it takes its detent's height, and holds
  /// nothing below the screen for VoiceOver to reach.
  public private(set) var isMoving = false
  @ObservationIgnored private var moves = 0

  public init() {}

  /// A finger has pulled the panel `dragged` points up.
  public func follow(_ dragged: Double) {
    _ = begin()
    self.dragged = dragged
  }

  /// Starts a move, outside the animation that carries it, and returns the number that ends it.
  public func begin() -> Int {
    moves += 1
    if !isMoving { isMoving = true }
    return moves
  }

  /// The finger let go: inside the animation that settles the panel.
  public func letGo() {
    dragged = 0
  }

  /// The move numbered `move` has landed, which leaves the panel at rest unless another move has
  /// begun since.
  public func end(_ move: Int) {
    if move == moves, isMoving { isMoving = false }
  }
}
