import OpenDivingKit
import SwiftUI

/// Labelled figures, side by side and wrapping where they do not fit.
struct FiguresRow: View {
  let figures: [Figure]

  var body: some View {
    if !figures.isEmpty {
      FlowLayout(spacing: 12, lineSpacing: 8) {
        ForEach(Array(figures.enumerated()), id: \.offset) { _, figure in
          VStack(alignment: .leading, spacing: 0) {
            Text(figure.label)
              .font(.caption)
            Text(figure.value ?? "-")
              .font(.body.weight(.bold))
              .foregroundStyle(figure.value == nil ? Color.secondary : Color.primary)
              .lineLimit(1)
          }
          .frame(minWidth: 72, alignment: .leading)
          .accessibilityElement(children: .combine)
        }
      }
    }
  }
}

#Preview {
  FiguresRow(figures: [
    Figure(label: "Dive time", value: "48 min"),
    Figure(label: "Max depth", value: "31 m"),
    Figure(label: "Water temp", value: nil),
  ])
  .padding()
}
