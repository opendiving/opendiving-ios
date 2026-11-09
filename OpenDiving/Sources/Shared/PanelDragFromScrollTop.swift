import SwiftUI
import UIKit

/// Hands a drag on the enclosing scroll view to the panel it sits in once the drag pulls down from
/// the top of the content, as a sheet's list does: the content holds at its top while the panel
/// follows the finger, back up as well as down, until the finger lifts. Placed in the scroll
/// view's content, it rides the scroll view's own pan, which a SwiftUI gesture alongside a scroll
/// view cannot hold still.
struct PanelDragFromScrollTop: UIViewRepresentable {
  /// The drag's translation since it took the panel, downward positive.
  let onChanged: (Double) -> Void
  /// Where the drag would have come to rest, flicked on as the scroll view would decelerate.
  let onEnded: (Double) -> Void

  func makeCoordinator() -> Coordinator { Coordinator() }

  func makeUIView(context: Context) -> UIView {
    let view = UIView()
    view.isUserInteractionEnabled = false
    return view
  }

  func updateUIView(_ view: UIView, context: Context) {
    context.coordinator.onChanged = onChanged
    context.coordinator.onEnded = onEnded
    guard context.coordinator.scrollView == nil else { return }
    // On the next turn, once SwiftUI has put the view in the hierarchy.
    DispatchQueue.main.async {
      var ancestor = view.superview
      while let current = ancestor {
        if let scrollView = current as? UIScrollView {
          context.coordinator.attach(to: scrollView)
          return
        }
        ancestor = current.superview
      }
    }
  }

  static func dismantleUIView(_ view: UIView, coordinator: Coordinator) {
    coordinator.detach()
  }

  @MainActor final class Coordinator: NSObject {
    var onChanged: (Double) -> Void = { _ in }
    var onEnded: (Double) -> Void = { _ in }
    weak var scrollView: UIScrollView?
    /// The pan's translation when it took the panel, or nil while the content scrolls.
    private var start: Double?

    func attach(to scrollView: UIScrollView) {
      self.scrollView = scrollView
      scrollView.panGestureRecognizer.addTarget(self, action: #selector(panned(_:)))
    }

    func detach() {
      scrollView?.panGestureRecognizer.removeTarget(self, action: #selector(panned(_:)))
    }

    @objc private func panned(_ pan: UIPanGestureRecognizer) {
      guard let scrollView else { return }
      let top = -scrollView.adjustedContentInset.top
      let translation = Double(pan.translation(in: nil).y)
      switch pan.state {
      case .began:
        start = nil
      case .changed:
        if start == nil, scrollView.contentOffset.y <= top, translation > 0 {
          start = translation
        }
        guard let start else { return }
        // The scroll view's own handler has already moved the content, and its bounce with it.
        scrollView.contentOffset.y = top
        onChanged(translation - start)
      case .ended, .cancelled, .failed:
        guard let start else { return }
        self.start = nil
        // Stops the deceleration the scroll view began from the flick, which would bounce.
        scrollView.setContentOffset(CGPoint(x: scrollView.contentOffset.x, y: top), animated: false)
        let velocity = pan.state == .ended ? Double(pan.velocity(in: nil).y) : 0
        let rate = Double(UIScrollView.DecelerationRate.normal.rawValue)
        onEnded(translation - start + velocity / 1000 * rate / (1 - rate))
      default:
        break
      }
    }
  }
}
