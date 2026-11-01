import SwiftUI

/// One record as a card, as the web's lists draw them: a band of backdrop — a map, or the
/// water standing in for one — above the details, which sit over its foot as it fades into
/// the card, in the page head's colours: the map fades into the card as the head's into the
/// page. However tall the details grow,
/// the band shows as much of itself. The backdrop is handed how many points of its foot the
/// details cover.
struct BackdropCardView<Backdrop: View, Details: View>: View {
  @ViewBuilder let backdrop: (_ coveredBottom: CGFloat) -> Backdrop
  @ViewBuilder let details: () -> Details

  @State private var detailsHeight: CGFloat = 0

  /// The band of backdrop above the details, the web's.
  private static var band: CGFloat { 132 }

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
        ZStack {
          backdrop(detailsHeight)
          LinearGradient(
            colors: [.clear, Color(.systemBackground)], startPoint: .center,
            endPoint: .bottom)
        }
        .allowsHitTesting(false)
      }
      .background(Color(.systemBackground))
      .clipShape(RoundedRectangle(cornerRadius: 12))
      .accessibilityElement(children: .combine)
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
