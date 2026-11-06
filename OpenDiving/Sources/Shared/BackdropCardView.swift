import OpenDivingKit
import SwiftUI

/// One record as a card, as the web's lists draw them: a band of backdrop — a map, or the
/// water standing in for one — above the details, which sit over its foot on frosted glass.
/// However tall the details grow, the band shows as much of itself. The backdrop is handed how
/// many points of its foot the details cover. A map's credit closes the details, as it does a
/// page head's, on the whole of the glass, and its line is kept on a card without one so that
/// neither a list's cards nor a card whose map arrives late change height.
struct BackdropCardView<Backdrop: View, Details: View>: View {
  @ViewBuilder let backdrop: (_ coveredBottom: CGFloat) -> Backdrop
  @ViewBuilder let details: () -> Details

  @State private var detailsHeight: CGFloat = 0
  @State private var credit: String?

  /// The band of backdrop above the details, the web's.
  private static var band: CGFloat { 132 }

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      details()
      creditLine
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding([.horizontal, .bottom], 12)
    .onGeometryChange(for: CGFloat.self) {
      $0.size.height
    } action: {
      detailsHeight = $0
    }
    .padding(.top, Self.band)
    .background {
      ZStack {
        backdrop(detailsHeight)
        glass
      }
      .allowsHitTesting(false)
    }
    .background(Color(.systemBackground))
    .onPreferenceChange(MapBackdropView.ShownCredit.self) { credit = $0 }
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .accessibilityElement(children: .combine)
  }

  private var creditLine: some View {
    ZStack {
      Text(verbatim: " ")
        .font(.caption2)
        .hidden()
      if let credit {
        AttributionLine(credits: [MapAttribution.display(credit)], underline: false)
          .transition(.opacity)
      }
    }
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
  BackdropCardView { coveredBottom in
    UnplacedBackdropView(icon: .tabDiveSite, coveredBottom: coveredBottom)
  } details: {
    VStack(alignment: .leading) {
      Text("Tiger Reef").font(.headline)
      Text("Dahab, Egypt").font(.subheadline).foregroundStyle(.secondary)
    }
  }
  .padding()
}
