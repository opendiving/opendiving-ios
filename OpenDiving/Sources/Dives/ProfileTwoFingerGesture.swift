import SwiftUI
import UIKit

/// Two fingers on the plot: UIKit's recognizers rather than `MagnifyGesture`, whose value holds
/// only where the fingers landed, so a pinch that slides would leave the dive behind, and which
/// offers no way to leave a two-finger swipe up or down to the page.
struct ProfileTwoFingerGesture: UIGestureRecognizerRepresentable {
  enum Kind {
    /// Fingers spreading or closing.
    case pinch
    /// Fingers moving sideways together. Up or down they leave it to the page.
    case slide
  }

  let kind: Kind
  var isEnabled = true
  /// Where the fingers' midpoint landed.
  let began: (_ x: Double) -> Void
  /// Where the midpoint is now, and how far the fingers have spread since they landed.
  let changed: (_ x: Double, _ scale: Double) -> Void
  let ended: () -> Void

  func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator { Coordinator() }

  func makeUIGestureRecognizer(context: Context) -> UIGestureRecognizer {
    let recognizer: UIGestureRecognizer
    switch kind {
    case .pinch:
      recognizer = UIPinchGestureRecognizer()
    case .slide:
      let pan = UIPanGestureRecognizer()
      pan.minimumNumberOfTouches = 2
      pan.maximumNumberOfTouches = 2
      recognizer = pan
    }
    recognizer.delegate = context.coordinator
    return recognizer
  }

  func updateUIGestureRecognizer(_ recognizer: UIGestureRecognizer, context: Context) {
    recognizer.isEnabled = isEnabled
  }

  func handleUIGestureRecognizerAction(_ recognizer: UIGestureRecognizer, context: Context) {
    let x = context.converter.localLocation.x
    switch recognizer.state {
    case .began: began(x)
    case .changed: changed(x, Double((recognizer as? UIPinchGestureRecognizer)?.scale ?? 1))
    case .ended, .cancelled, .failed: ended()
    default: break
    }
  }

  final class Coordinator: NSObject, UIGestureRecognizerDelegate {
    func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
      guard let pan = recognizer as? UIPanGestureRecognizer else { return true }
      let velocity = pan.velocity(in: pan.view)
      return abs(velocity.x) > abs(velocity.y)
    }

    /// The readout claims a press as the first finger lands, so two fingers have to be able to
    /// start beside it. The page's scroll stays exclusive, whichever of the two starts first
    /// having the fingers, and so do a pinch and a slide, which both move the window.
    func gestureRecognizer(
      _ recognizer: UIGestureRecognizer,
      shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
    ) -> Bool {
      !(other.view is UIScrollView) && !(other.delegate is Coordinator)
    }
  }
}
