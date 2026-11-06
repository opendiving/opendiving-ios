import SwiftUI

/// One record as a card, as the web's lists draw them: a band of backdrop — a map, or the
/// water standing in for one — above the details, which sit over its foot on frosted glass.
/// However tall the details grow, the band shows as much of itself. The backdrop is handed how
/// many points of its foot the details cover.
struct BackdropCardView<Backdrop: View, Details: View>: View {
  @ViewBuilder let backdrop: (_ coveredBottom: CGFloat) -> Backdrop
  @ViewBuilder let details: () -> Details

  @State private var detailsHeight: CGFloat = 0

  /// The band of backdrop above the details, the web's.
  private static var band: CGFloat { 132 }
  /// How far above the details the glass starts coming in. It is whole where they start, sooner
  /// than the web's: a material blurs harder, so a map's labels would ghost behind the name.
  private static var glassRise: CGFloat { 48 }

  var body: some View {
    details()
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding([.horizontal, .bottom], 12)
      .onGeometryChange(for: CGFloat.self) {
        $0.size.height
      } action: {
        detailsHeight = $0
      }
      .padding(.top, Self.band)
      .background {
        ZStack(alignment: .bottom) {
          backdrop(detailsHeight)
          glass
        }
        .allowsHitTesting(false)
      }
      .background(Color(.systemBackground))
      .clipShape(RoundedRectangle(cornerRadius: 12))
      .accessibilityElement(children: .combine)
  }

  /// A material rather than `glassEffect`, which is iOS 26's and for controls over the content
  /// rather than the content: one path for every iOS the app runs on, and its own tint lands on
  /// the colours of the web's glass, so nothing is laid over it.
  private var glass: some View {
    Rectangle()
      .fill(.thinMaterial)
      .frame(height: detailsHeight + Self.glassRise)
      .mask(alignment: .top) {
        VStack(spacing: 0) {
          LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
            .frame(height: Self.glassRise)
          Color.black
        }
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
