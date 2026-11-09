import OpenDivingKit
import SwiftUI

/// The chips over a title: vocabulary abbreviations and a site's mark bordered in the text's
/// colour, tags filled. Nothing at all when there are none.
struct ChipsRow: View {
  let chips: [Chip]

  var body: some View {
    if !chips.isEmpty {
      FlowLayout(spacing: 4) {
        ForEach(Array(chips.enumerated()), id: \.offset) { _, chip in
          ChipView(chip: chip)
        }
      }
    }
  }
}

private struct ChipView: View {
  let chip: Chip

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: 3)
    HStack(spacing: 2) {
      if case .site(let mark) = chip.kind {
        DiveSiteMarkIcon(mark: mark, side: 12, relativeTo: .caption2)
      }
      Text(chip.text).accessibilityLabel(chip.accessibilityLabel)
    }
    .font(.caption2.weight(.semibold))
    .lineLimit(1)
    .padding(.horizontal, 4)
    .padding(.vertical, 1)
    .foregroundStyle(isFilled ? Color.white : Color.primary)
    .background {
      switch chip.kind {
      case .vocabulary, .site: shape.strokeBorder(Color.primary)
      case .tag, .new: shape.fill(Color.brandTeal)
      case .modified: shape.fill(Color.brandCoral)
      }
    }
  }

  private var isFilled: Bool {
    switch chip.kind {
    case .vocabulary, .site: false
    case .tag, .new, .modified: true
    }
  }
}

#Preview {
  ChipsRow(chips: [
    Chip(text: "FW", accessibilityLabel: "Fresh water", kind: .vocabulary),
    Chip(text: "CCR", accessibilityLabel: "Closed circuit", kind: .vocabulary),
    DiveSiteMark.commons.chip, DiveSiteMark.proposed.chip, DiveSiteMark.private.chip,
    .tag("wreck"), .tag("night"),
  ])
  .padding()
}
