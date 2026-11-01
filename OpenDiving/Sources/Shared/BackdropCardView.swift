import SwiftUI

/// One record as a card, as the web's lists draw them: a band of backdrop — a map, or the
/// water standing in for one — above the details, which sit over its foot on a glass that
/// comes in from above them. However tall the details grow, the band shows as much of
/// itself. The backdrop is handed how many points of its foot the details cover.
struct BackdropCardView<Backdrop: View, Details: View>: View {
  @ViewBuilder let backdrop: (_ coveredBottom: CGFloat) -> Backdrop
  @ViewBuilder let details: () -> Details

  @State private var detailsHeight: CGFloat = 0

  /// The band of backdrop above the details, the web's.
  private static var band: CGFloat { 132 }
  /// How far above the details the glass starts coming in.
  private static var glassLead: CGFloat { 48 }

  var body: some View {
    details()
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding([.horizontal, .bottom], 12)
      .onGeometryChange(for: CGFloat.self) {
        $0.size.height
      } action: {
        detailsHeight = $0
      }
      .background(alignment: .bottom) {
        glass
          .frame(height: detailsHeight + Self.glassLead)
      }
      .padding(.top, Self.band)
      .background {
        backdrop(detailsHeight)
          .allowsHitTesting(false)
      }
      .background(Color(.secondarySystemGroupedBackground))
      .clipShape(RoundedRectangle(cornerRadius: 12))
      .accessibilityElement(children: .combine)
  }

  /// The card's colour, clear at the top and whole from just under it.
  private var glass: some View {
    let card = Color(.secondarySystemGroupedBackground)
    let whole = min(1, 80 / max(1, detailsHeight + Self.glassLead))
    return LinearGradient(
      stops: [
        .init(color: card.opacity(0), location: 0),
        .init(color: card.opacity(0.85), location: whole),
        .init(color: card.opacity(0.85), location: 1),
      ], startPoint: .top, endPoint: .bottom
    )
    .allowsHitTesting(false)
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
