import OpenDivingKit
import SwiftUI

/// A trip or a dive site as a card on its list: a map of its places, then its name, the
/// facts line under it and what the diver's dives there add up to, as the web's cards.
struct RecordCardView: View {
  let content: RecordCardContent
  /// What the water shows where there is no map: the record's own icon.
  let icon: OpenDivingKit.Icon

  var body: some View {
    BackdropCardView { coveredBottom in
      ZStack {
        UnplacedBackdropView(icon: icon, coveredBottom: coveredBottom)
        if !content.points.isEmpty || content.mapsTheWorldWhenEmpty {
          MapBackdropView(
            points: content.points, fixes: [], coveredBottom: coveredBottom,
            worldWhenEmpty: content.mapsTheWorldWhenEmpty)
        }
      }
    } details: {
      VStack(alignment: .leading, spacing: 6) {
        ChipsRow(chips: content.chips)
        CardDetailLines(title: content.title, facts: content.facts, figures: content.figures)
      }
    }
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
        ], mapsTheWorldWhenEmpty: true), icon: .tabLuggage)
    RecordCardView(
      content: RecordCardContent(
        title: "Tiger Reef",
        facts: [
          Fact(text: "Dahab, Egypt"),
          Fact(text: "To 30 m", icon: .arrowDownToLine, accessibilityLabel: "Depth"),
        ],
        figures: [Figure(label: "Dives", value: "2"), Figure(label: "Deepest", value: nil)]),
      icon: .tabDiveSite)
  }
  .padding()
  .background(Color(.systemGroupedBackground))
  .environment(Session.stub(transport: StubTransport(routes: [:])))
}
