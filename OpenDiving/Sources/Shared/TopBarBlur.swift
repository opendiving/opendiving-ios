import SwiftUI

/// A blur fading down from the top of the screen. At rest it is light and over the status bar
/// alone, which keeps the status bar readable over a map or a photo drawn up under it while the
/// map stays sharp under the navigation bar's buttons. `cover`, from 0 to 1, grows it into a veil
/// over the whole bar, as the system's soft scroll-edge effect draws one — which the system only
/// shows or hides, and lets no page fade by degrees.
struct TopBarBlur: View {
  /// How far it has grown into the veil over the bar.
  var cover: Double = 0
  /// Where the navigation bar ends, which the full veil reaches.
  var barFoot: CGFloat = 0

  private static let fullRadius = 8.0
  /// How far the light blur runs on past the status bar.
  private static let fade: CGFloat = 6

  var body: some View {
    let scene = UIApplication.shared.connectedScenes.lazy.compactMap { $0 as? UIWindowScene }.first
    let rest = (scene?.statusBarManager?.statusBarFrame.height ?? 0) + Self.fade
    ZStack {
      ProgressiveBlur(edge: .top, radius: 1 + (Self.fullRadius - 1) * cover, hold: 0.5)
      LinearGradient(
        stops: [
          .init(color: Color.pageBackground.opacity(0.85 * cover), location: 0),
          .init(color: Color.pageBackground.opacity(0.5 * cover), location: 0.6),
          .init(color: .clear, location: 1),
        ],
        startPoint: .top, endPoint: .bottom
      )
      .allowsHitTesting(false)
      .accessibilityHidden(true)
    }
    .frame(height: rest + max(barFoot - rest, 0) * cover)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .ignoresSafeArea()
  }
}

#Preview {
  ZStack {
    LinearGradient(colors: [.teal, .orange], startPoint: .leading, endPoint: .trailing)
      .ignoresSafeArea()
    TopBarBlur(cover: 0.5, barFoot: 116)
  }
}
