import SwiftUI

extension EnvironmentValues {
  /// How far a page head reaches up under the screen's top bar: its map fills it, and its pins
  /// keep clear of it.
  @Entry var heroTopInset: CGFloat = 0
}

extension View {
  /// Lets a page that opens with a ``HeroView`` draw its head to the top of the screen, under
  /// the status bar and the navigation bar's buttons, and refresh with `refresh` when pulled down.
  func heroUnderTopBar(refresh: (@Sendable () async -> Void)? = nil) -> some View {
    modifier(HeroUnderTopBar(refresh: refresh))
  }
}

/// The system's refresh spinner sits behind the page, where the head's map drawn above it hides
/// it, so a page under the top bar shows its own just below the bar.
private struct HeroUnderTopBar: ViewModifier {
  let refresh: (@Sendable () async -> Void)?

  @State private var inset: CGFloat = 0
  @State private var pull: CGFloat = 0
  @State private var isRefreshing = false

  func body(content: Content) -> some View {
    refreshable(content)
      .environment(\.heroTopInset, inset)
      .ignoresSafeArea(edges: .top)
      .onScrollGeometryChange(for: CGFloat.self) {
        max(-$0.contentOffset.y - $0.contentInsets.top, 0)
      } action: { _, pulled in
        pull = pulled
      }
      .overlay(alignment: .top) {
        if refresh != nil {
          ProgressView()
            .frame(width: 32, height: 32)
            .background(Color(.systemBackground).opacity(0.8), in: Circle())
            .padding(.top, 8)
            .opacity(isRefreshing ? 1 : min(max((pull - 8) / 40, 0), 1))
            .animation(.easeOut(duration: 0.2), value: isRefreshing)
            .accessibilityHidden(true)
        }
      }
      .onGeometryChange(for: CGFloat.self) {
        $0.safeAreaInsets.top
      } action: {
        inset = $0
      }
  }

  @ViewBuilder
  private func refreshable(_ content: Content) -> some View {
    if let refresh {
      content.refreshable {
        isRefreshing = true
        await refresh()
        isRefreshing = false
      }
    } else {
      content
    }
  }
}
