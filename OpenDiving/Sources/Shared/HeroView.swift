import OpenDivingKit
import SwiftUI

/// The head of a dive's, a trip's or a site's page, or of the diver's profile: a map of its
/// places, up under the top bar on a page that lets it (``SwiftUI/View/heroUnderTopBar()``) and
/// on above the page for a pull-down to show, fading into the page's ``Color/pageBackground``,
/// under its chips, title, facts and figures, and the map's credit after them — or, with
/// `detailsOnGlass`, the credit over the map and the rest on a card of glass. `leading` stands
/// before the title and the facts — the profile's picture. A record with nowhere to put on a
/// map, or on an instance with no map to draw, gets the band without one.
struct HeroView<Leading: View>: View {
  let content: HeroContent
  var detailsOnGlass = false
  /// The least each figure takes across: wider sets fewer in a row.
  var figureMinWidth: CGFloat = 72
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
      if detailsOnGlass {
        creditLine
        details
          .padding(12)
          .background { GlassCard() }
      } else {
        details
        creditLine
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
    // Over the band with no map too, which would otherwise end in a seam against the page.
    .background {
      LinearGradient(
        colors: [.clear, Color.pageBackground], startPoint: .center, endPoint: .bottom)
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

  private var details: some View {
    VStack(alignment: .leading, spacing: 6) {
      ChipsRow(chips: content.chips)
      HStack(alignment: .top, spacing: 12) {
        leading()
        // On glass the line sits close under the name, as a card's does.
        VStack(alignment: .leading, spacing: detailsOnGlass ? 2 : 6) {
          TitleLine(
            title: content.title, isCourse: content.isCourse, rating: content.rating,
            font: .title2.bold())
          FactsLine(facts: content.facts)
        }
      }
      FiguresRow(figures: content.figures, minWidth: figureMinWidth)
        .padding(.top, 4)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  @ViewBuilder private var creditLine: some View {
    if let credit {
      AttributionLine(credits: [MapAttribution.display(credit)], underline: false)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
  }
}

extension HeroView where Leading == EmptyView {
  init(content: HeroContent) {
    self.init(content: content) { EmptyView() }
  }
}

/// Glass as a folder on the home screen has it: what lies behind blurred through, a light rim
/// catching its edge, and a soft shadow lifting it off the map. Drawn from a material, which blurs
/// on every version, rather than the system's glass effect, which iOS 26 draws close to opaque
/// over dark tiles.
private struct GlassCard: View {
  private static let rim = LinearGradient(
    stops: [
      .init(color: .white.opacity(0.5), location: 0),
      .init(color: .white.opacity(0.1), location: 0.35),
      .init(color: .white.opacity(0.05), location: 0.65),
      .init(color: .white.opacity(0.3), location: 1),
    ],
    startPoint: .topLeading, endPoint: .bottomTrailing)

  var body: some View {
    RoundedRectangle.formSection
      .fill(.ultraThinMaterial)
      .overlay { RoundedRectangle.formSection.fill(Color.white.opacity(0.06)) }
      .overlay { RoundedRectangle.formSection.strokeBorder(Self.rim, lineWidth: 1) }
      .shadow(color: .black.opacity(0.2), radius: 16, y: 6)
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
