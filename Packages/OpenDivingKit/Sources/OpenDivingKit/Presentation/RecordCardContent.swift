/// Everything a trip's or a site's card on its list draws: the name, the facts line under
/// it and what the diver's dives there add up to.
public struct RecordCardContent: Hashable, Sendable {
  public var title: String
  public var facts: [Fact]
  public var figures: [Figure]

  public init(title: String, facts: [Fact] = [], figures: [Figure] = []) {
    self.title = title
    self.facts = facts
    self.figures = figures
  }
}
