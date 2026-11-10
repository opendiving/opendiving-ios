import OpenDivingKit
import SwiftUI

/// The head of a dive's, a trip's or a site's page, or of the diver's profile: a map of its
/// places, up under the top bar on a page that lets it (``SwiftUI/View/heroUnderTopBar()``) and
/// on above the page for a pull-down to show, fading into the page, under its chips, title,
/// facts and figures, and the map's credit after them. `leading` stands before the title and
/// the facts — the profile's picture. A record with nowhere to put on a map, or on an instance
/// with no map to draw, gets the band without one.
struct HeroView<Leading: View>: View {
  let content: HeroContent
  @ViewBuilder let leading: () -> Leading

  /// How far the band is drawn above the head, out of sight until a pull-down reveals it.
  private static var pullReach: CGFloat { 400 }

  @Environment(\.heroTopInset) private var topInset
  @State private var height: CGFloat = 0
  @State private var detailsHeight: CGFloat = 0
  @State private var credit: String?

  private var hasMap: Bool {
    !content.points.isEmpty || !content.fixes.isEmpty || content.mapsTheWorldWhenEmpty
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      ChipsRow(chips: content.chips)
      HStack(alignment: .top, spacing: 12) {
        leading()
        VStack(alignment: .leading, spacing: 6) {
          TitleLine(
            title: content.title, isCourse: content.isCourse, rating: content.rating,
            font: .title2.bold())
          FactsLine(facts: content.facts)
        }
      }
      FiguresRow(figures: content.figures)
        .padding(.top, 4)
      if let credit {
        AttributionLine(credits: [MapAttribution.display(credit)], underline: false)
          .frame(maxWidth: .infinity, alignment: .trailing)
      }
    }
    .padding()
    .onGeometryChange(for: CGFloat.self) {
      $0.size.height
    } action: {
      detailsHeight = $0
    }
    .frame(maxWidth: .infinity, minHeight: 280 + topInset, alignment: .bottomLeading)
    .onGeometryChange(for: CGFloat.self) {
      $0.size.height
    } action: {
      height = $0
    }
    .background {
      if hasMap {
        LinearGradient(
          colors: [.clear, Color(.systemBackground)], startPoint: .center, endPoint: .bottom)
      }
    }
    .background(alignment: .bottom) {
      ZStack {
        Color(.secondarySystemBackground)
        if hasMap {
          MapBackdropView(
            points: content.points, fixes: content.fixes,
            overflowTop: Self.pullReach, coveredTop: topInset, coveredBottom: detailsHeight,
            worldWhenEmpty: content.mapsTheWorldWhenEmpty, credit: $credit
          )
          .allowsHitTesting(false)
          .accessibilityHidden(true)
        }
      }
      .frame(height: height + Self.pullReach)
    }
  }
}

extension HeroView where Leading == EmptyView {
  init(content: HeroContent) {
    self.init(content: content) { EmptyView() }
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
