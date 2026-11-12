import OpenDivingKit
import SwiftUI

/// A trip or a dive site as a card on its list: a map of its places, then its name, the facts
/// line under it, what the diver's dives on it add up to and whatever the list adds under those,
/// as the web's cards.
struct RecordCardView<Footer: View>: View {
  let content: RecordCardContent
  /// What the water shows where there is no map: the record's own icon.
  let icon: OpenDivingKit.Icon
  @ViewBuilder var footer: () -> Footer

  var body: some View {
    BackdropCardView { frame in
      ZStack {
        UnplacedBackdropView(icon: icon, coveredBottom: frame.coveredBottom)
        if !content.points.isEmpty || content.mapsTheWorldWhenEmpty {
          let covers = frame.mapCovers()
          MapBackdropView(
            points: content.points, fixes: [], coveredTop: covers.top,
            coveredBottom: covers.bottom,
            worldWhenEmpty: content.mapsTheWorldWhenEmpty)
        }
      }
    } details: {
      VStack(alignment: .leading, spacing: 8) {
        CardDetailLines(title: content.title, facts: content.facts, figures: content.figures)
        footer()
      }
    }
  }
}

extension RecordCardView where Footer == EmptyView {
  init(content: RecordCardContent, icon: OpenDivingKit.Icon) {
    self.init(content: content, icon: icon) { EmptyView() }
  }
}

#Preview {
  RecordCardView(
    content: RecordCardContent(
      title: "Dahab 2026 (September)",
      facts: [Fact(text: "Sep 6 - Sep 20, 2026"), Fact(text: "Dahab, Egypt +1")],
      figures: [
        Figure(label: "Dives", value: "26"), Figure(label: "Dive sites", value: "9"),
        Figure(label: "Species seen", value: "41"),
      ], mapsTheWorldWhenEmpty: true), icon: .tabLuggage
  )
  .padding()
  .background(Color(.systemGroupedBackground))
  .environment(Session.stub(transport: StubTransport(routes: [:])))
}
