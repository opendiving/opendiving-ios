import OpenDivingKit
import SwiftUI

/// The head of a dive's or a trip's page, or of the diver's profile: a map of its
/// places, up under the top bar on a page that lets it (``SwiftUI/View/heroUnderTopBar()``) and
/// on above the page for a pull-down to show, fading into the page's ``Color/pageBackground``,
/// under its chips, title, facts and figures, and the map's credit after them — or, with
/// `detailsOnGlass`, the credit over the map and the rest on a card of glass. `leading` stands
/// before the title and the facts — the profile's picture. A record with nowhere to put on a
/// map, or on an instance with no map to draw, gets the band without one; a species gets its
/// photo in place of a map.
struct HeroView<Leading: View>: View {
  let content: HeroContent
  var backdrop = HeroBackdrop.map
  var detailsOnGlass = false
  /// The least each figure takes across: wider sets fewer in a row.
  var figureMinWidth = FiguresRow.defaultMinWidth
  @ViewBuilder let leading: () -> Leading

  /// How far the band is drawn above the head, out of sight until a pull-down reveals it.
  private static var pullReach: CGFloat { 400 }

  @Environment(\.heroTopInset) private var topInset
  @State private var height: CGFloat = 0
  @State private var detailsHeight: CGFloat = 0
  @State private var credit: String?

  private var hasMap: Bool {
    backdrop == .map
      && (!content.points.isEmpty || !content.fixes.isEmpty || content.mapsTheWorldWhenEmpty)
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
      ZStack(alignment: .bottom) {
        // Water past the world's edge too, which a pull-down on a map of the world reaches.
        Color.mapWater
        if case .photo(let data, let placeholder) = backdrop {
          photo(data, placeholder: placeholder)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
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

  /// Decorative: the title over it says what it is. Framed on what the bar and the details leave
  /// showing and cut at the head's top, its blurred copy filling the pull-down's reach above.
  @ViewBuilder private func photo(_ data: Data?, placeholder: OpenDivingKit.Icon) -> some View {
    if let data, let image = UIImage(data: data) {
      PlacedPhotoView(data: data, image: image) { photo, frame in
        .hero(
          photoWidth: photo.width, photoHeight: photo.height, width: frame.width,
          top: Self.pullReach, uncoveredTop: Self.pullReach + topInset,
          uncoveredBottom: Self.pullReach + height - detailsHeight)
      }
    } else {
      UnplacedBackdropView(icon: placeholder, coveredTop: topInset, coveredBottom: detailsHeight)
        .frame(height: height)
        .clipped()
    }
  }

  private var details: some View {
    VStack(alignment: .leading, spacing: 6) {
      ChipsRow(chips: content.chips)
      HStack(alignment: .top, spacing: 12) {
        leading()
        // On glass the line sits under the name as a figure's value does under its label.
        VStack(alignment: .leading, spacing: detailsOnGlass ? 0 : 6) {
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
  init(content: HeroContent, backdrop: HeroBackdrop = .map, detailsOnGlass: Bool = false) {
    self.init(content: content, backdrop: backdrop, detailsOnGlass: detailsOnGlass) {
      EmptyView()
    }
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

#Preview("Species photos") {
  ScrollView {
    VStack(spacing: 0) {
      ForEach(PlacedPhotoView.previewPhotos, id: \.self) { photo in
        HeroView(
          content: HeroContent(
            title: "Sea goldie", facts: [Fact(text: "Pseudanthias squamipinnis")],
            figures: [Figure(label: "Dives", value: "4"), Figure(label: "Dive sites", value: "3")]),
          backdrop: .photo(photo, placeholder: .fish), detailsOnGlass: true)
      }
    }
  }
  .environment(Session.stub(transport: StubTransport(routes: [:])))
}
