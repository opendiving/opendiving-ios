/// The head of a dive's, a trip's or a site's page: a map of its places behind the
/// chips, the title, the facts line and the figures.
public struct HeroContent: Hashable, Sendable {
  public var title: String
  public var isCourse: Bool
  public var rating: Int?
  public var chips: [Chip]
  public var facts: [Fact]
  public var figures: [Figure]
  /// The record's places: a dive's sites, a trip's geocoded parts, a site itself.
  public var points: [MapPoint]
  /// Where a dive computer put the diver, drawn apart from the places.
  public var fixes: [MapPoint]

  public init(
    title: String,
    isCourse: Bool = false,
    rating: Int? = nil,
    chips: [Chip] = [],
    facts: [Fact] = [],
    figures: [Figure] = [],
    points: [MapPoint] = [],
    fixes: [MapPoint] = []
  ) {
    self.title = title
    self.isCourse = isCourse
    self.rating = rating
    self.chips = chips
    self.facts = facts
    self.figures = figures
    self.points = points
    self.fixes = fixes
  }
}
