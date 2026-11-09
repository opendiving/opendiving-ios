import Observation

/// How far a finger has pulled the site finder's panel up from its detent. It is held apart from
/// the finder so that only what rides on the panel's edge is drawn again as the finger moves,
/// rather than the finder, its list and its map on every frame.
@MainActor
@Observable
public final class SiteFinderPanelDrag {
  public var dragged = 0.0

  public init() {}
}
