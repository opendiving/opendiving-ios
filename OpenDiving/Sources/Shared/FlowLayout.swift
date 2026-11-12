import SwiftUI

/// Lays its children out left to right, wrapping onto a new line when the next one does
/// not fit: chips, facts and figures, whose count the record decides.
///
/// A child marked `flowSeparator()` travels with the child after it, so a line never ends on
/// one, and is left out where it would start a line.
struct FlowLayout: Layout {
  var spacing: CGFloat = 6
  var lineSpacing: CGFloat = 4

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let lines = arrange(subviews, width: proposal.width ?? .infinity).lines
    let width = lines.map(\.width).max() ?? 0
    let height = lines.map(\.height).reduce(0, +) + lineSpacing * CGFloat(max(lines.count - 1, 0))
    return CGSize(width: width, height: height)
  }

  func placeSubviews(
    in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
  ) {
    let arrangement = arrange(subviews, width: bounds.width)
    for index in arrangement.dropped {
      subviews[index].place(at: bounds.origin, proposal: .zero)
    }
    var y = bounds.minY
    for line in arrangement.lines {
      var x = bounds.minX
      for index in line.indices {
        let size = subviews[index].sizeThatFits(.unspecified)
        subviews[index].place(
          at: CGPoint(x: x, y: y + (line.height - size.height) / 2),
          proposal: ProposedViewSize(width: min(size.width, bounds.width), height: size.height))
        x += min(size.width, bounds.width) + spacing
      }
      y += line.height + lineSpacing
    }
  }

  private struct Line {
    var indices: [Int] = []
    var width: CGFloat = 0
    var height: CGFloat = 0
  }

  private func arrange(_ subviews: Subviews, width: CGFloat) -> (lines: [Line], dropped: [Int]) {
    var lines: [Line] = []
    var dropped: [Int] = []
    var line = Line()
    var index = subviews.startIndex
    while index < subviews.endIndex {
      let group =
        subviews[index][FlowSeparator.self] && index + 1 < subviews.endIndex
        ? [index, index + 1] : [index]
      let sizes = group.map { subviews[$0].sizeThatFits(.unspecified) }
      let widths = sizes.map { min($0.width, width) }
      let groupWidth = widths.reduce(0, +) + spacing * CGFloat(group.count - 1)
      if !line.indices.isEmpty && line.width + spacing + groupWidth > width {
        lines.append(line)
        line = Line()
      }
      for (member, size) in zip(group, sizes) {
        if line.indices.isEmpty && subviews[member][FlowSeparator.self] {
          dropped.append(member)
          continue
        }
        let itemWidth = min(size.width, width)
        line.width = line.indices.isEmpty ? itemWidth : line.width + spacing + itemWidth
        line.height = max(line.height, size.height)
        line.indices.append(member)
      }
      index += group.count
    }
    if !line.indices.isEmpty { lines.append(line) }
    return (lines, dropped)
  }
}

private nonisolated struct FlowSeparator: LayoutValueKey {
  static let defaultValue = false
}

extension View {
  /// Marks a child of a `FlowLayout` as the separator before the next one.
  func flowSeparator() -> some View {
    // The layout drops a separator by proposing it no room, where this draws nothing.
    ViewThatFits(in: .horizontal) {
      self
      Color.clear.frame(width: 0, height: 0)
    }
    .layoutValue(key: FlowSeparator.self, value: true)
  }
}
