import SwiftUI

extension EnvironmentValues {
  /// How far a page head reaches up under the screen's top bar: its map fills it, and its pins
  /// keep clear of it.
  @Entry var heroTopInset: CGFloat = 0
}

extension View {
  /// Lets a page that opens with a ``HeroView`` draw its head to the top of the screen, under
  /// the status bar and the navigation bar's buttons.
  func heroUnderTopBar() -> some View {
    modifier(HeroUnderTopBar())
  }
}

private struct HeroUnderTopBar: ViewModifier {
  @State private var inset: CGFloat = 0

  func body(content: Content) -> some View {
    content
      .environment(\.heroTopInset, inset)
      .ignoresSafeArea(edges: .top)
      .onGeometryChange(for: CGFloat.self) {
        $0.safeAreaInsets.top
      } action: {
        inset = $0
      }
  }
}
