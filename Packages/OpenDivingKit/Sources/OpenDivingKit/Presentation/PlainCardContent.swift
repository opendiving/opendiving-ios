/// A record with nothing to draw behind it, as a card on its list: its name with its badges,
/// the facts line under it and its figures, as the web's plain card.
public struct PlainCardContent: Hashable, Sendable {
  public var title: String
  public var badges: [Badge]
  public var facts: [Fact]
  /// Said muted in place of the facts line where there are none: a gear set's *Empty*.
  public var emptyLine: String?
  /// None for a card that carries no figures, which then ends under its line.
  public var figures: [Figure]

  public init(
    title: String, badges: [Badge] = [], facts: [Fact] = [], emptyLine: String? = nil,
    figures: [Figure] = []
  ) {
    self.title = title
    self.badges = badges
    self.facts = facts
    self.emptyLine = emptyLine
    self.figures = figures
  }
}
