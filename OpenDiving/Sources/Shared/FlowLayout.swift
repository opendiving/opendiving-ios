import SwiftUI

/// Lays its children out left to right, wrapping onto a new line when the next one does
/// not fit: chips, facts and figures, whose count the record decides.
struct FlowLayout: Layout {
  var spacing: CGFloat = 6
  var lineSpacing: CGFloat = 4

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let lines = arrange(subviews, width: proposal.width ?? .infinity)
    let width = lines.map(\.width).max() ?? 0
    let height = lines.map(\.height).reduce(0, +) + lineSpacing * CGFloat(max(lines.count - 1, 0))
    return CGSize(width: width, height: height)
  }

  func placeSubviews(
    in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
  ) {
    var y = bounds.minY
    for line in arrange(subviews, width: bounds.width) {
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

  private func arrange(_ subviews: Subviews, width: CGFloat) -> [Line] {
    var lines: [Line] = []
    var line = Line()
    for index in subviews.indices {
      let size = subviews[index].sizeThatFits(.unspecified)
      let itemWidth = min(size.width, width)
      let needed = line.indices.isEmpty ? itemWidth : line.width + spacing + itemWidth
      if !line.indices.isEmpty && needed > width {
        lines.append(line)
        line = Line()
      }
      line.width = line.indices.isEmpty ? itemWidth : line.width + spacing + itemWidth
      line.height = max(line.height, size.height)
      line.indices.append(index)
    }
    if !line.indices.isEmpty { lines.append(line) }
    return lines
  }
}
