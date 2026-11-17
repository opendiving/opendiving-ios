import SwiftUI

/// The logo's second line, its filled bubble, coral C and *ommons*, as a page's title in the
/// navigation bar: what the page's head becomes as it scrolls under the bar. It tells the page where
/// it is drawn on screen.
struct CommonsBarTitle: View {
  var onFrame: (CGRect) -> Void = { _ in }

  @ScaledMetric(relativeTo: .headline) private var height: CGFloat = 20

  var body: some View {
    // Scaled with the text size, no further than the bar has room for.
    let shown = min(height, 26)
    let width = shown * CommonsLogo.bar.width / CommonsLogo.bar.height
    ZStack {
      Image("CommonsBarMark").resizable()
      Image("CommonsBarOmmons").resizable().foregroundStyle(Color.commonsLogoInk)
    }
    .frame(width: width, height: shown)
    .onGeometryChange(for: CGRect.self) {
      $0.frame(in: .global)
    } action: {
      onFrame($0)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("OpenDiving Commons")
    .accessibilityAddTraits(.isHeader)
  }
}

#Preview {
  CommonsBarTitle()
}
