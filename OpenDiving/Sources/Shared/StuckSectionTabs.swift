import OpenDivingKit
import SwiftUI

/// A page's tabs held under the top bar, by their names alone, once the page scrolls its
/// ``ScrollingSectionTabs`` up to it: their names land where the scrolled tabs' were, so the swap
/// does not show. The band over what was above them fades in and out rather than hiding it at
/// once. It overlays the top of the page's scroll view, under ``View/heroUnderTopBar(refresh:)``,
/// and what the tabs show is ``View/hiddenUnderTopBar()``.
struct StuckSectionTabs<Section: TabSection>: View {
  @Binding var selection: Section
  let isStuck: Bool
  var title: (Section) -> String = { $0.title }
  let onReselect: () -> Void
  @Environment(\.heroTopInset) private var topInset

  var body: some View {
    VStack(spacing: 0) {
      Color.pageBackground
        .frame(height: topInset)
        .opacity(isStuck ? 1 : 0)
        .animation(.easeInOut(duration: 0.25), value: isStuck)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
      if isStuck {
        // Inside the row alone: a colour's background otherwise runs up under the bar, over the
        // band, and hides what it fades over at once.
        SectionTabs(selection: $selection, showsIcons: false, title: title, onReselect: onReselect)
          .background { Color.pageBackground }
      }
    }
  }
}

/// The tabs under a page's head, which report where their names sit and when those reach the
/// top bar, any icons already gone under it, for ``StuckSectionTabs`` to stand in for them.
struct ScrollingSectionTabs<Section: TabSection>: View {
  @Binding var selection: Section
  @Binding var isStuck: Bool
  @Binding var top: CGFloat
  var title: (Section) -> String = { $0.title }
  let onReselect: () -> Void
  @Environment(\.heroTopInset) private var topInset
  @ScaledMetric(relativeTo: .title2) private var iconHeight = SectionTabs<Section>.iconRowHeight

  private var iconRow: CGFloat {
    Section.allCases.contains { $0.icon != nil } ? iconHeight : 0
  }

  var body: some View {
    SectionTabs(selection: $selection, title: title, onReselect: onReselect)
      .readsTabsTop($top, below: iconRow)
      .onGeometryChange(for: Bool.self) {
        [top = topInset - iconRow] in
        $0.frame(in: .scrollView).minY <= top
      } action: {
        isStuck = $0
      }
      // The copy held at the top stands for them while it shows. Their icons stay, to fade out
      // under its band with the page above them; their names, underline and hairline go, which
      // would show twice over the copy's while it fades.
      .mask {
        VStack(spacing: 0) {
          Rectangle().frame(height: iconRow)
          Rectangle().opacity(isStuck ? 0 : 1)
        }
      }
      .accessibilityHidden(isStuck)
  }
}

extension View {
  /// Keeps what is under a page's tabs from showing above the copy of them held under the bar:
  /// a fast scroll brings it up there while the band over the bar is still fading in.
  func hiddenUnderTopBar() -> some View {
    modifier(HiddenUnderTopBar())
  }
}

private struct HiddenUnderTopBar: ViewModifier {
  @Environment(\.heroTopInset) private var topInset

  func body(content: Content) -> some View {
    content.mask {
      GeometryReader { proxy in
        Rectangle()
          .padding(.top, min(max(topInset - proxy.frame(in: .global).minY, 0), proxy.size.height))
          // Room for the cards' shadows, which a mask the content's own size would cut.
          .padding([.horizontal, .bottom], -32)
      }
    }
  }
}
