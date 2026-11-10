import OpenDivingKit
import SwiftUI

/// A record with nothing to draw behind it — gear, a course — as a card on its list: its name
/// with its badges beside it, the facts line under it and its figures, on a card's fill, as the
/// web's plain card.
struct PlainCardView: View {
  let content: PlainCardContent

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      VStack(alignment: .leading, spacing: 2) {
        FlowLayout(spacing: 8, lineSpacing: 4) {
          Text(content.title)
            .font(.headline)
          ForEach(Array(content.badges.enumerated()), id: \.offset) { _, badge in
            BadgeView(badge)
          }
        }
        FactsLine(facts: content.facts, color: .primary)
      }
      FiguresRow(figures: content.figures)
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.cardFill, in: .formSection)
    .accessibilityElement(children: .combine)
  }
}

#Preview {
  VStack(spacing: 12) {
    PlainCardView(
      content: PlainCardContent(
        title: "Twinset",
        badges: [Badge("Rented", style: .outline), Badge("Due soon", style: .coral)],
        facts: [Fact(text: "Cylinder"), Fact(text: "Faber"), Fact(text: "2 × 12 L")],
        figures: [
          Figure(label: "Dives", value: "42"), Figure(label: "Dive time", value: "38h 12m"),
        ]
      ))
    PlainCardView(
      content: PlainCardContent(
        title: "Advanced Open Water", badges: [Badge("Completed", style: .primary)],
        facts: [Fact(text: "PADI"), Fact(text: "Sep 6 - Sep 8, 2026")]))
  }
  .padding()
  .background(Color.pageBackground)
}
