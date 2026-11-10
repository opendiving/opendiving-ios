import OpenDivingKit
import SwiftUI
import UIKit

/// Glass as a folder on the home screen has it: what lies behind blurred through, a light rim
/// catching its edge, and a soft shadow lifting it off the map. The blur is the cards' own, at a
/// radius of its own, which no material lets one set; not the system's glass effect either, which
/// iOS 26 draws close to opaque over dark tiles.
struct GlassCard: View {
  var shape: RoundedRectangle = .formSection

  private static let blurRadius = 6.0

  /// Lighter than what lies behind in both appearances, as the folder's glass is.
  private static let frost = Color(
    UIColor { traits in
      UIColor(white: 1, alpha: traits.userInterfaceStyle == .dark ? 0.1 : 0.45)
    })

  private static let rim = LinearGradient(
    stops: [
      .init(color: .white.opacity(0.5), location: 0),
      .init(color: .white.opacity(0.1), location: 0.35),
      .init(color: .white.opacity(0.05), location: 0.65),
      .init(color: .white.opacity(0.3), location: 1),
    ],
    startPoint: .topLeading, endPoint: .bottomTrailing)

  var body: some View {
    ZStack {
      ProgressiveBlur(edge: .top, radius: Self.blurRadius, hold: 1)
        .clipShape(shape)
      // A material's tint, which the bare blur has none of, keeps the text readable.
      shape.fill(Self.frost)
      shape.strokeBorder(Self.rim, lineWidth: 1)
    }
    .background { shadow }
  }

  /// Outside the card alone: under the glass it would be blurred into it.
  private var shadow: some View {
    shape
      .fill(.black)
      .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
      .mask {
        Rectangle()
          .padding(-48)
          .overlay { shape.blendMode(.destinationOut) }
          .compositingGroup()
      }
  }
}

#Preview {
  ZStack {
    UnplacedBackdropView(icon: .tabDiveSite, coveredBottom: 0)
    Text("Tiger Reef").font(.headline).padding(12).background { GlassCard() }
  }
  .frame(height: 200)
}
