import SwiftUI
import UIKit

extension View {
  /// `refreshable`, with the bubble spinner in place of the system's.
  func bubbleRefreshable(_ action: @escaping @MainActor () async -> Void) -> some View {
    modifier(BubbleRefreshable(action: action))
  }
}

/// The spinner hangs from the top of the refresh control SwiftUI gives the scroll view, whose own
/// spinner it clears. A pull opens its gap above a large title rather than at the top of the safe
/// area, and the control's top is the only place that shows. Its height lags the scroll by a
/// frame, so how far the spinner shows comes from the scroll itself, and while a refresh runs it
/// stays whole: the gap held open then may count as inset rather than pull.
private struct BubbleRefreshable: ViewModifier {
  let action: @MainActor () async -> Void

  @State private var scrollView = WeakScrollView()
  @State private var pull: CGFloat = 0
  @State private var gapTop: CGFloat = 0
  @State private var origin: CGFloat = 0
  @State private var isRefreshing = false

  func body(content: Content) -> some View {
    content
      .refreshable {
        isRefreshing = true
        await action()
        isRefreshing = false
      }
      .background(EnclosingScrollView(found: scrollView))
      .onScrollGeometryChange(for: CGFloat.self) {
        max(-$0.contentOffset.y - $0.contentInsets.top, 0)
      } action: { _, pulled in
        pull = pulled
        guard let control = scrollView.view?.refreshControl else { return }
        control.tintColor = .clear
        gapTop = control.convert(control.bounds, to: nil).minY
      }
      .onGeometryChange(for: CGFloat.self) {
        $0.frame(in: .global).minY
      } action: {
        origin = $0
      }
      .overlay(alignment: .top) {
        ZStack {
          // Built only while it shows: hidden by opacity, its timeline would draw every frame.
          if isRefreshing || shown > 0 {
            BubbleSpinner()
              .offset(y: gapTop - origin + (isRefreshing ? 44 : min(pull, 44)) / 2 - 10)
              .opacity(isRefreshing ? 1 : shown)
              .transition(.opacity)
              .accessibilityHidden(true)
          }
        }
        .animation(.easeOut(duration: 0.2), value: isRefreshing)
      }
  }

  /// How far into a pull the spinner has faded in, from none to whole.
  private var shown: Double {
    min(max(Double(pull - 8) / 40, 0), 1)
  }
}

@MainActor private final class WeakScrollView {
  weak var view: UIScrollView?
}

/// Finds the nearest scroll view with a refresh control around where it is placed.
private struct EnclosingScrollView: UIViewRepresentable {
  let found: WeakScrollView

  func makeUIView(context: Context) -> UIView {
    let view = UIView()
    view.isUserInteractionEnabled = false
    return view
  }

  func updateUIView(_ view: UIView, context: Context) {
    guard found.view == nil else { return }
    // On the next turn, once SwiftUI has put the view in the hierarchy.
    DispatchQueue.main.async {
      var ancestor = view.superview
      while let current = ancestor {
        if let scrollView = Self.firstRefreshable(in: current) {
          scrollView.refreshControl?.tintColor = .clear
          found.view = scrollView
          return
        }
        ancestor = current.superview
      }
    }
  }

  private static func firstRefreshable(in view: UIView) -> UIScrollView? {
    var queue = [view]
    while !queue.isEmpty {
      let next = queue.removeFirst()
      if let scrollView = next as? UIScrollView, scrollView.refreshControl != nil {
        return scrollView
      }
      queue.append(contentsOf: next.subviews)
    }
    return nil
  }
}
