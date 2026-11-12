/// Everything a trip's or a dive site's card on its list draws: the name, the facts line under
/// it and what the diver's dives on it add up to.
public struct RecordCardContent: Hashable, Sendable {
  public var title: String
  public var facts: [Fact]
  public var figures: [Figure]
  /// The record's places: a trip's geocoded parts, a site's pin.
  public var points: [MapPoint]
  /// A record with no place still draws a map, of the whole world: a trip's, which is a
  /// journey before it has a destination.
  public var mapsTheWorldWhenEmpty: Bool

  public init(
    title: String, facts: [Fact] = [], figures: [Figure] = [],
    points: [MapPoint] = [],
    mapsTheWorldWhenEmpty: Bool = false
  ) {
    self.title = title
    self.facts = facts
    self.figures = figures
    self.points = points
    self.mapsTheWorldWhenEmpty = mapsTheWorldWhenEmpty
  }
}
