import SwiftUI

/// Its views side by side across the row, each as wide as it would be alone plus an equal share
/// of the width left over, where an `HStack` of flexible views gives each an equal width instead.
/// Its ideal width is its views' own, so a `ViewThatFits` passes it over when they do not fit.
struct EqualPaddingRow: Layout {
  var spacing: CGFloat

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
    let natural = sizes.reduce(0) { $0 + $1.width } + gaps(subviews)
    return CGSize(width: proposal.width ?? natural, height: sizes.map(\.height).max() ?? 0)
  }

  func placeSubviews(
    in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
  ) {
    let widths = subviews.map { $0.sizeThatFits(.unspecified).width }
    let left = bounds.width - widths.reduce(0, +) - gaps(subviews)
    let share = max(left, 0) / CGFloat(max(subviews.count, 1))
    var x = bounds.minX
    for (subview, width) in zip(subviews, widths) {
      subview.place(
        at: CGPoint(x: x, y: bounds.midY), anchor: .leading,
        proposal: ProposedViewSize(width: width + share, height: bounds.height))
      x += width + share + spacing
    }
  }

  private func gaps(_ subviews: Subviews) -> CGFloat {
    spacing * CGFloat(max(subviews.count - 1, 0))
  }
}
