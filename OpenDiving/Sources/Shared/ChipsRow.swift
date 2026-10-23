import OpenDivingKit
import SwiftUI

/// The chips over a title: vocabulary abbreviations bordered in the text's colour, tags
/// filled. Nothing at all when there are none.
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
    Text(chip.text)
      .font(.caption2.weight(.semibold))
      .lineLimit(1)
      .padding(.horizontal, 4)
      .padding(.vertical, 1)
      .foregroundStyle(chip.kind == .tag ? Color.white : Color.primary)
      .background {
        switch chip.kind {
        case .vocabulary: shape.strokeBorder(Color.primary)
        case .tag: shape.fill(Color.teal)
        }
      }
      .accessibilityLabel(chip.accessibilityLabel)
  }
}

#Preview {
  ChipsRow(chips: [
    Chip(text: "FW", accessibilityLabel: "Fresh water", kind: .vocabulary),
    Chip(text: "CCR", accessibilityLabel: "Closed circuit", kind: .vocabulary),
    .tag("wreck"), .tag("night"),
  ])
  .padding()
}
