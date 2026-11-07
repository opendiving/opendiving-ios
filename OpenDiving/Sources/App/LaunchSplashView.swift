import OpenDivingKit
import SwiftUI

/// The web's launch splash without its wordmark: white bubbles rising over coral, sized and placed
/// by the web's numbers. Still, as the logo, under Reduce Motion.
struct LaunchSplashView: View {
  var body: some View {
    GeometryReader { proxy in
      // The width of 26 of the logo's units: the web's `min(22vmin, 160px)`.
      let mark = min(min(proxy.size.width, proxy.size.height) * 0.22, 160)
      BubbleSpinner(width: mark * SplashBubbles.bounds.width / 26)
        // Above true centre, which reads as low: the usual optical lift, plus the distance the
        // bubbles' weight drops below their box over a loop.
        .offset(y: -(mark * 0.07 + proxy.size.height * 0.03))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .foregroundStyle(.white)
    .background(Color(.sRGB, red: 1, green: 127 / 255, blue: 80 / 255))
    .ignoresSafeArea()
    .accessibilityElement()
    .accessibilityLabel("Loading OpenDiving")
  }
}

#Preview {
  LaunchSplashView()
}
