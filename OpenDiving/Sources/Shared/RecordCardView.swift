import OpenDivingKit
import SwiftUI

/// A trip or a dive site as a card on its list: its name, the facts line under it and what
/// the diver's dives there add up to.
struct RecordCardView: View {
  let content: RecordCardContent

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      TitleLine(title: content.title)
      FactsLine(facts: content.facts)
      FiguresRow(figures: content.figures)
        .padding(.top, 2)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(12)
    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    .accessibilityElement(children: .combine)
  }
}

#Preview {
  VStack(spacing: 12) {
    RecordCardView(
      content: RecordCardContent(
        title: "Dahab 2026 (September)",
        facts: [Fact(text: "Sep 6 - Sep 20, 2026"), Fact(text: "Dahab, Egypt +1")],
        figures: [
          Figure(label: "Dives", value: "26"), Figure(label: "Dive sites", value: "9"),
          Figure(label: "Species seen", value: "41"),
        ]))
    RecordCardView(
      content: RecordCardContent(
        title: "Tiger Reef",
        facts: [
          Fact(text: "Dahab, Egypt"),
          Fact(text: "To 30 m", systemImage: "arrow.down.to.line", accessibilityLabel: "Depth"),
        ],
        figures: [Figure(label: "Dives", value: "2"), Figure(label: "Deepest", value: nil)]))
  }
  .padding()
  .background(Color(.systemGroupedBackground))
}
