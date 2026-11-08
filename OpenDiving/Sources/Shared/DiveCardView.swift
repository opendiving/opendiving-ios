import OpenDivingKit
import SwiftUI

/// One dive as a card, in every list of dives: a map of its sites and fixes, its depth
/// silhouette over the map's foot and its chips over the silhouette's, then its title, facts
/// and figures, as the web's dive card.
struct DiveCardView: View {
  let content: DiveCardContent

  private static let silhouetteHeight: CGFloat = 56
  private static let silhouetteGap: CGFloat = 4
  private static let chipsHeight: CGFloat = 26
  /// Between a pin's foot and the silhouette's line under it.
  private static let pinClearance: CGFloat = 2

  var body: some View {
    BackdropCardView { frame in
      // The water's icon centres above the silhouette and the chips rather than behind them.
      let aboveProfile =
        hasOutline
        ? frame.coveredBottom + Self.silhouetteGap + Self.silhouetteHeight
        : content.chips.isEmpty ? frame.coveredBottom : frame.coveredBottom + Self.chipsHeight
      ZStack {
        UnplacedBackdropView(icon: .tabDive, coveredBottom: aboveProfile)
        if !content.points.isEmpty || !content.fixes.isEmpty {
          let covers = frame.mapCovers(pinCentre: pinCentre(frame))
          MapBackdropView(
            points: content.points, fixes: content.fixes, coveredTop: covers.top,
            coveredBottom: covers.bottom)
        }
      }
    } details: {
      CardDetailLines(
        title: content.title, isCourse: content.isCourse, rating: content.rating,
        facts: content.facts, figures: content.figures
      )
      .frame(maxWidth: .infinity, alignment: .leading)
      // With the details rather than in the backdrop, or the glass would blur the curve away.
      .background(alignment: .top) {
        if hasOutline {
          DiveSilhouetteView(depths: content.outline)
            .frame(height: Self.silhouetteHeight)
            .offset(y: -Self.silhouetteHeight - Self.silhouetteGap)
        }
      }
      // Over the foot of the band rather than above the title in the flow, so a dive with
      // chips is as tall as one without.
      .overlay(alignment: .topLeading) {
        ChipsRow(chips: content.chips)
          .alignmentGuide(.top) { $0[.bottom] + 4 }
      }
    }
  }

  private var hasOutline: Bool { content.outline.count > 1 }

  /// A card's own, or higher where the silhouette's line comes up under the pin, the middle of
  /// a card that spans the silhouette less the details' padding either side.
  private func pinCentre(_ frame: CardBackdropFrame) -> CGFloat {
    let span = frame.width - 24
    guard hasOutline, span > 0 else { return CardBackdropFrame.pinCentre }
    let half = MapMarker.diameter / 2 / span
    guard let shallowest = DiveOutline.shallowest(content.outline, from: 0.5 - half, to: 0.5 + half)
    else { return CardBackdropFrame.pinCentre }
    let line =
      CardBackdropFrame.band - Self.silhouetteGap - Self.silhouetteHeight
      + shallowest * Self.silhouetteHeight
    return min(CardBackdropFrame.pinCentre, line - Self.pinClearance - MapMarker.diameter / 2)
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
            Fact(text: "Ocean Star", icon: .ship, accessibilityLabel: "Boat"),
            Fact(icon: .diveComputer, accessibilityLabel: "1 dive computer"),
          ],
          figures: [
            Figure(label: "Dive time", value: "48 min"), Figure(label: "Max depth", value: "31 m"),
            Figure(label: "Water temp", value: "24 °C"),
          ],
          outline: [0, 0.4, 0.9, 1, 0.7, 0.5, 0.15, 0.15, 0],
          points: [MapPoint(name: "Blue Hole", latitude: 28.5722, longitude: 34.5372)]))
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
  .environment(Session.stub(transport: StubTransport(routes: [:])))
}
