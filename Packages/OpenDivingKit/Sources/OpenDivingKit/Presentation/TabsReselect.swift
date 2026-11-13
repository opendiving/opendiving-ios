/// Where a tap on a page's chosen tab scrolls it: to where the tabs reach the top bar, the
/// section's start just under them, from above that point or below it; from there, or where the
/// page cannot scroll that far, back to its head.
public enum TabsReselect: Hashable, Sendable {
  case head
  /// The content offset that brings the tabs to the bar.
  case tabs(offset: Double)

  /// From the page's content `offset`, the range it scrolls through, and the offset at which
  /// the tabs reach the bar.
  public init(offset: Double, range: ClosedRange<Double>, tabsAtBar: Double) {
    let target = min(max(tabsAtBar, range.lowerBound), range.upperBound)
    // Within a point is there: a scroll that ends on a fraction of a pixel still reads as one.
    self = abs(target - offset) < 1 ? .head : .tabs(offset: target)
  }
}
