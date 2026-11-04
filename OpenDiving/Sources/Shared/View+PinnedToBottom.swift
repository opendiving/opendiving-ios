import SwiftUI

extension View {
  /// Pins `bar` under a scrolling view. From iOS 26 the content fades out behind it as it does
  /// behind the navigation bar; before that the bar has that bar's material.
  @ViewBuilder func pinnedToBottom<Bar: View>(@ViewBuilder _ bar: () -> Bar) -> some View {
    if #available(iOS 26, *) {
      // Named, because a glass button in the bar can otherwise leave the fade off.
      scrollEdgeEffectStyle(.soft, for: .bottom)
        .safeAreaBar(edge: .bottom, spacing: 0, content: bar)
    } else {
      safeAreaInset(edge: .bottom, spacing: 0) { bar().background(.bar) }
    }
  }
}
