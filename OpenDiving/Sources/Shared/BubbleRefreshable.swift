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
/// follows the control instead: the gap held open then may count as inset rather than pull.
private struct BubbleRefreshable: ViewModifier {
  let action: @MainActor () async -> Void

  @State private var scrollView = WeakScrollView()
  @State private var pull: CGFloat = 0
  @State private var gapTop: CGFloat = 0
  @State private var controlTop: CGFloat = 0
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
      // Every scroll, not only a change in the pull: during a refresh the control moves with the
      // rows while the pull stays at nothing.
      .onScrollGeometryChange(for: ScrollPosition.self) {
        ScrollPosition(offset: $0.contentOffset.y, inset: $0.contentInsets.top)
      } action: { _, position in
        pull = max(-position.offset - position.inset, 0)
        guard let control = scrollView.view?.refreshControl else { return }
        control.tintColor = .clear
        controlTop = control.convert(control.bounds, to: nil).minY
        if pull > 0 { gapTop = controlTop }
      }
      .onGeometryChange(for: CGFloat.self) {
        $0.frame(in: .global).minY
      } action: {
        origin = $0
      }
      .overlay(alignment: .top) {
        ZStack {
          // Built only while it shows: hidden by opacity, its timeline would draw every frame.
          if opacity > 0 {
            BubbleSpinner()
              .offset(y: center - origin - 10)
              .opacity(opacity)
              .transition(.opacity)
              .accessibilityHidden(true)
          }
        }
        .animation(.easeOut(duration: 0.2), value: isRefreshing)
      }
  }

  /// While a refresh runs the spinner rides on the control, so it scrolls away with the rows.
  private var center: CGFloat {
    isRefreshing ? controlTop + 22 : gapTop + min(pull, 44) / 2
  }

  /// How far into a pull the spinner has faded in, or during a refresh how much of it is still
  /// below the top of the gap, from none to whole.
  private var opacity: Double {
    let shown = isRefreshing ? (controlTop + 44 - gapTop) / 44 : (pull - 8) / 40
    return min(max(Double(shown), 0), 1)
  }
}

private struct ScrollPosition: Equatable {
  var offset: CGFloat
  var inset: CGFloat
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
