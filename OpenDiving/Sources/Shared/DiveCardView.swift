import OpenDivingKit
import SwiftUI

/// One dive as a card, in every list of dives: its chips, title, facts and figures, over
/// its depth outline across the foot of the card.
struct DiveCardView: View {
  let content: DiveCardContent

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      ChipsRow(chips: content.chips)
      TitleLine(title: content.title, isCourse: content.isCourse, rating: content.rating)
      FactsLine(facts: content.facts)
      FiguresRow(figures: content.figures)
        .padding(.top, 2)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(12)
    .background(alignment: .bottom) {
      if content.outline.count > 1 {
        DepthOutlineShape(depths: content.outline)
          .fill(Color.accentColor.opacity(0.15))
          .frame(height: 44)
          .padding(.horizontal, 12)
          .padding(.bottom, 6)
          .accessibilityHidden(true)
      }
    }
    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    .accessibilityElement(children: .combine)
  }
}

#Preview {
  ScrollView {
    VStack(spacing: 12) {
      DiveCardView(
        content: DiveCardContent(
          title: "#212 Blue Hole +1",
          isCourse: true,
          rating: 4,
          chips: [
            Chip(text: "FW", accessibilityLabel: "Fresh water", kind: .vocabulary), .tag("night"),
          ],
          facts: [
            Fact(text: "Apr 4, 2021, 10:04"), Fact(text: "Dahab, Egypt"),
            Fact(text: "Ocean Star", systemImage: "ferry", accessibilityLabel: "Boat"),
            Fact(systemImage: "paperclip", accessibilityLabel: "Recording attached"),
          ],
          figures: [
            Figure(label: "Dive time", value: "48 min"), Figure(label: "Max depth", value: "31 m"),
            Figure(label: "Water temp", value: "24 °C"),
          ],
          outline: [0, 0.4, 0.9, 1, 0.7, 0.5, 0.15, 0.15, 0]))
      DiveCardView(
        content: DiveCardContent(
          title: "Dive #3",
          figures: [
            Figure(label: "Dive time", value: "12 min"),
            Figure(label: "Max depth", value: nil),
          ]))
    }
    .padding()
  }
  .background(Color(.systemGroupedBackground))
}
