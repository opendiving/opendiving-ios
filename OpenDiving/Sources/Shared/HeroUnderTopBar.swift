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
    softTopEdge(refreshable(content))
      .environment(\.heroTopInset, inset)
      .ignoresSafeArea(edges: .top)
      .onScrollGeometryChange(for: CGFloat.self) {
        max(-$0.contentOffset.y - $0.contentInsets.top, 0)
      } action: { _, pulled in
        pull = pulled
      }
      .overlay(alignment: .top) {
        ZStack {
          // Built only while it shows: hidden by opacity, its timeline would draw every frame.
          if refresh != nil, isRefreshing || pulledFar > 0 {
            BubbleSpinner()
              .frame(width: 32, height: 32)
              .background(Color(.systemBackground).opacity(0.8), in: Circle())
              .padding(.top, 8)
              .opacity(isRefreshing ? 1 : pulledFar)
              .transition(.opacity)
              .accessibilityHidden(true)
          }
        }
        .animation(.easeOut(duration: 0.2), value: isRefreshing)
      }
      .onGeometryChange(for: CGFloat.self) {
        $0.safeAreaInsets.top
      } action: {
        inset = $0
      }
  }

  /// How far into a pull the spinner has faded in, from none to whole.
  private var pulledFar: Double {
    min(max(Double(pull - 8) / 40, 0), 1)
  }

  /// Named, because a bar item drawing glass of its own, with the bar's hidden, otherwise draws
  /// the bar's edge hard across the map.
  @ViewBuilder
  private func softTopEdge(_ content: some View) -> some View {
    if #available(iOS 26, *) {
      content.scrollEdgeEffectStyle(.soft, for: .top)
    } else {
      content
    }
  }

  @ViewBuilder
  private func refreshable(_ content: Content) -> some View {
    if let refresh {
      content.refreshable {
        isRefreshing = true
        await RefreshRead.run(refresh)
        isRefreshing = false
      }
    } else {
      content
    }
  }
}
