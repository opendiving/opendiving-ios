import SwiftUI

/// The Commons mark and *Commons* as a page's title in the navigation bar: what the page's head
/// becomes as it scrolls under the bar. It tells the page where both are drawn on screen.
struct CommonsBarTitle: View {
  var onMarkFrame: (CGRect) -> Void = { _ in }
  var onWordFrame: (CGRect) -> Void = { _ in }

  @ScaledMetric(relativeTo: .headline) private var height: CGFloat = 15

  var body: some View {
    HStack(spacing: 2) {
      CommonsMark(side: 15 * CommonsName.markScale, relativeTo: .headline)
        .onGeometryChange(for: CGRect.self) {
          $0.frame(in: .global)
        } action: {
          onMarkFrame($0)
        }
      Image("CommonsWord")
        .resizable()
        .frame(width: height * CommonsName.commonsWidth / CommonsName.commonsHeight, height: height)
        .foregroundStyle(Color.primary.opacity(0.75))
        .onGeometryChange(for: CGRect.self) {
          $0.frame(in: .global)
        } action: {
          onWordFrame($0)
        }
    }
    .dynamicTypeSize(...DynamicTypeSize.xxLarge)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("OpenDiving Commons")
    .accessibilityAddTraits(.isHeader)
  }
}

#Preview {
  CommonsBarTitle()
}
