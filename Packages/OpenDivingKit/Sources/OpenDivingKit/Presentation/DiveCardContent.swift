/// Everything a dive card draws, as plain values: one dive in any list of dives.
public struct DiveCardContent: Hashable, Sendable {
  /// `#212 Blue Hole +1`, or `Dive #212` with no site.
  public var title: String
  /// The dive was part of a course; drawn as a graduation cap after the title.
  public var isCourse: Bool
  /// The diver's rating out of five; drawn as stars after the title.
  public var rating: Int?
  public var chips: [Chip]
  public var facts: [Fact]
  /// Up to three.
  public var figures: [Figure]
  /// The depth outline, evenly spaced in time, each point a fraction of the deepest one —
  /// 0 at the surface, 1 at the bottom. Empty draws no outline.
  public var outline: [Double]

  public init(
    title: String,
    isCourse: Bool = false,
    rating: Int? = nil,
    chips: [Chip] = [],
    facts: [Fact] = [],
    figures: [Figure] = [],
    outline: [Double] = []
  ) {
    self.title = title
    self.isCourse = isCourse
    self.rating = rating
    self.chips = chips
    self.facts = facts
    self.figures = figures
    self.outline = outline
  }
}
