import SwiftUI
import UIKit

/// Hands a drag on the enclosing scroll view to the panel it sits in, as a sheet's list does: a
/// pull down from the top of the content, and a swipe up while the panel has room to grow. The
/// content holds still while the panel follows the finger, back as well as forth, until the finger
/// lifts — or, on a swipe up, until the panel stands at its tallest, where the content scrolls on
/// under the same finger. Placed in the scroll view's content, it rides the scroll view's own pan,
/// which a SwiftUI gesture alongside a scroll view cannot hold still.
struct PanelDragFromScrollTop: UIViewRepresentable {
  /// How far the panel can grow, read as a drag begins.
  let roomAbove: () -> Double
  /// The drag's translation since it took the panel, downward positive.
  let onChanged: (Double) -> Void
  /// The speed the finger let go at, in points a second downward, or 0 when the drag was taken
  /// or the panel reached its tallest.
  let onEnded: (Double) -> Void

  func makeCoordinator() -> Coordinator { Coordinator() }

  func makeUIView(context: Context) -> UIView {
    let view = UIView()
    view.isUserInteractionEnabled = false
    return view
  }

  func updateUIView(_ view: UIView, context: Context) {
    context.coordinator.roomAbove = roomAbove
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
    var roomAbove: () -> Double = { 0 }
    var onChanged: (Double) -> Void = { _ in }
    var onEnded: (Double) -> Void = { _ in }
    weak var scrollView: UIScrollView?
    /// The pan's translation when it took the panel, or nil while the content scrolls.
    private var start: Double?
    /// Where the content holds while the panel follows the finger.
    private var held = 0.0
    /// The room the panel had to grow as the pan began.
    private var room = 0.0
    /// The pan's translation when the panel reached its tallest and gave the content the rest.
    private var handedOver: Double?

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
        handedOver = nil
        room = roomAbove()
      case .changed:
        // The scroll view's own handler has already moved the content, and its bounce with it,
        // so the content is put where the finger has it from the hand-over on.
        if let handedOver {
          scrollView.contentOffset.y = max(top, held + handedOver - translation)
          return
        }
        if start == nil {
          if scrollView.contentOffset.y <= top, translation > 0 {
            start = translation
            held = top
          } else if room > 0, translation < 0 {
            start = translation
            // Where the content stood before this pan's first move scrolled it.
            held = max(top, Double(scrollView.contentOffset.y) + translation)
          }
        }
        guard let start else { return }
        scrollView.contentOffset.y = held
        let moved = translation - start
        if -moved >= room, room > 0 {
          handedOver = translation
          onChanged(-room)
          onEnded(0)
          return
        }
        onChanged(moved)
      case .ended, .cancelled, .failed:
        guard start != nil, handedOver == nil else { return }
        start = nil
        // Stops the deceleration the scroll view began from the flick, which would bounce.
        scrollView.setContentOffset(
          CGPoint(x: scrollView.contentOffset.x, y: held), animated: false)
        onEnded(pan.state == .ended ? Double(pan.velocity(in: nil).y) : 0)
      default:
        break
      }
    }
  }
}
