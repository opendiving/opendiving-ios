import OpenDivingKit
import SwiftUI

/// One record as a card, as the web's lists draw them: a band of backdrop — a map, or the
/// water standing in for one — above the details, which sit over its foot on frosted glass.
/// However tall the details grow, the band shows as much of itself. The backdrop is handed the
/// card's width and how many points of its foot the details cover. A map's credit sits in the
/// card's top corner on glass of its own, out of the details, so a list's cards are one height
/// whichever of them has a map.
struct BackdropCardView<Backdrop: View, Details: View>: View {
  @ViewBuilder let backdrop: (CardBackdropFrame) -> Backdrop
  @ViewBuilder let details: () -> Details

  @State private var detailsSize = CGSize.zero
  @State private var credit: MapBackdropView.CardCredit?

  var body: some View {
    details()
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding([.horizontal, .bottom], 12)
      .onGeometryChange(for: CGSize.self) {
        $0.size
      } action: {
        detailsSize = $0
      }
      .padding(.top, CardBackdropFrame.band)
      .background {
        ZStack {
          backdrop(
            CardBackdropFrame(width: detailsSize.width, coveredBottom: detailsSize.height))
          glass
        }
        .allowsHitTesting(false)
      }
      .background(Color(.systemBackground))
      .overlay(alignment: .topTrailing) { creditChip }
      .onPreferenceChange(MapBackdropView.CardCredit.Key.self) { credit = $0 }
      .clipShape(RoundedRectangle(cornerRadius: 12))
      .accessibilityElement(children: .combine)
  }

  /// On glass of its own, as bare text cannot be read on the map's labels.
  private var creditChip: some View {
    ZStack {
      if let credit, credit.isShown {
        AttributionLine(credits: [MapAttribution.display(credit.text)], underline: false)
          .multilineTextAlignment(.trailing)
          .padding(.horizontal, 6)
          .padding(.vertical, 2)
          .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 6))
          .opacity(0.8)
          .transition(.opacity)
      }
    }
    .padding(8)
    .frame(maxWidth: .infinity, alignment: .trailing)
    .animation(.easeOut(duration: 0.3), value: credit)
    .allowsHitTesting(false)
  }

  /// A material rather than `glassEffect`, which is iOS 26's and for controls over the content
  /// rather than the content: one path for every iOS the app runs on, and its own tint lands on
  /// the colours of the web's glass, so nothing is laid over it.
  private var glass: some View {
    Rectangle()
      .fill(.thinMaterial)
      .mask {
        LinearGradient(colors: [.clear, .black], startPoint: .center, endPoint: .bottom)
      }
  }
}

#Preview {
  BackdropCardView { frame in
    UnplacedBackdropView(icon: .tabDiveSite, coveredBottom: frame.coveredBottom)
  } details: {
    VStack(alignment: .leading) {
      Text("Tiger Reef").font(.headline)
      Text("Dahab, Egypt").font(.subheadline).foregroundStyle(.secondary)
    }
  }
  .padding()
}
