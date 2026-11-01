import OpenDivingKit
import SwiftUI

/// The head of a dive's, a trip's or a site's page: a map of its places, fading into the
/// page, under its chips, title, facts and figures, and the map's credit after them. A record
/// with nowhere to put on a map, or on an instance with no map to draw, gets the band without
/// one.
struct HeroView: View {
  let content: HeroContent

  @State private var detailsHeight: CGFloat = 0
  @State private var credit: String?

  var body: some View {
    ZStack(alignment: .bottomLeading) {
      Color(.secondarySystemBackground)
      if !content.points.isEmpty || !content.fixes.isEmpty {
        MapBackdropView(
          points: content.points, fixes: content.fixes, coveredBottom: detailsHeight,
          credit: $credit
        )
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        LinearGradient(
          colors: [.clear, Color(.systemBackground)], startPoint: .center, endPoint: .bottom)
      }
      VStack(alignment: .leading, spacing: 6) {
        ChipsRow(chips: content.chips)
        TitleLine(
          title: content.title, isCourse: content.isCourse, rating: content.rating,
          font: .title2.bold())
        FactsLine(facts: content.facts)
        FiguresRow(figures: content.figures)
          .padding(.top, 4)
        if let credit {
          AttributionLine(credits: [credit])
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
      }
      .padding()
      .onGeometryChange(for: CGFloat.self) {
        $0.size.height
      } action: {
        detailsHeight = $0
      }
    }
    .frame(minHeight: 280)
  }
}

#Preview {
  ScrollView {
    HeroView(
      content: HeroContent(
        title: "#212 Blue Hole",
        rating: 5,
        chips: [.tag("deep")],
        facts: [Fact(text: "Apr 4, 2021, 10:04"), Fact(text: "Dahab, Egypt")],
        figures: [
          Figure(label: "Dive time", value: "48 min"), Figure(label: "Max depth", value: "31 m"),
          Figure(label: "Water temp", value: "24 °C"), Figure(label: "Visibility", value: "30 m"),
        ],
        points: [MapPoint(name: "Blue Hole", latitude: 28.5722, longitude: 34.5372)],
        fixes: [MapPoint(name: "Exit", latitude: 28.5735, longitude: 34.5361)]))
  }
  .environment(Session.stub(transport: StubTransport(routes: [:])))
}
