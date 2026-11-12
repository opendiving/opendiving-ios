import OpenDivingKit
import SwiftUI

extension View {
  /// Keeps `reselect` at where a tap on the page's chosen tab scrolls this scroll view, for tabs
  /// whose names sit `tabsTop` down its content and reach the bar at the head's top inset.
  func tabsReselect(_ reselect: Binding<TabsReselect>, tabsTop: CGFloat) -> some View {
    modifier(TabsReselectReading(reselect: reselect, tabsTop: tabsTop))
  }

  /// Reports how far down the ``NamedCoordinateSpace/pageContent`` this view's top sits, plus
  /// `below`.
  func readsTabsTop(_ top: Binding<CGFloat>, below: CGFloat = 0) -> some View {
    onGeometryChange(for: CGFloat.self) {
      $0.frame(in: .pageContent).minY + below
    } action: {
      top.wrappedValue = $0
    }
  }
}

extension CoordinateSpaceProtocol where Self == NamedCoordinateSpace {
  /// The whole of what a page scrolls, named on the stack directly inside its scroll view, whose
  /// top is where its content offset counts from.
  nonisolated static var pageContent: Self { .named("pageContent") }
}

extension ScrollPosition {
  mutating func scroll(to reselect: TabsReselect) {
    switch reselect {
    case .head: scrollTo(edge: .top)
    case .tabs(let offset): scrollTo(y: offset)
    }
  }
}

/// Read in the scroll view, under ``View/heroUnderTopBar(refresh:)``, which sets the inset.
private struct TabsReselectReading: ViewModifier {
  @Binding var reselect: TabsReselect
  let tabsTop: CGFloat
  @Environment(\.heroTopInset) private var topInset

  func body(content: Content) -> some View {
    content.onScrollGeometryChange(for: TabsReselect.self) {
      [tabsAtBar = tabsTop - topInset] geometry in
      let top = -geometry.contentInsets.top
      let bottom =
        geometry.contentSize.height + geometry.contentInsets.bottom
        - geometry.containerSize.height
      return TabsReselect(
        offset: geometry.contentOffset.y, range: top...max(top, bottom), tabsAtBar: tabsAtBar)
    } action: {
      reselect = $1
    }
  }
}
