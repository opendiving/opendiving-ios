import SwiftUI
import UIKit

/// A swipe in from the screen's right edge, as the system's back swipe comes in from the left.
/// Every other pan waits for it to fail, which it does as soon as a touch lands away from the
/// edge, so the map and the panel move only for a swipe that is not this one.
struct RightEdgeSwipe: UIGestureRecognizerRepresentable {
  var isEnabled = true
  let onSwipe: () -> Void

  func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator { Coordinator() }

  func makeUIGestureRecognizer(context: Context) -> UIScreenEdgePanGestureRecognizer {
    let recognizer = UIScreenEdgePanGestureRecognizer()
    recognizer.edges = .right
    recognizer.delegate = context.coordinator
    return recognizer
  }

  func updateUIGestureRecognizer(
    _ recognizer: UIScreenEdgePanGestureRecognizer, context: Context
  ) {
    recognizer.isEnabled = isEnabled
  }

  func handleUIGestureRecognizerAction(
    _ recognizer: UIScreenEdgePanGestureRecognizer, context: Context
  ) {
    if recognizer.state == .began { onSwipe() }
  }

  final class Coordinator: NSObject, UIGestureRecognizerDelegate {
    func gestureRecognizer(
      _ recognizer: UIGestureRecognizer,
      shouldBeRequiredToFailBy other: UIGestureRecognizer
    ) -> Bool {
      other is UIPanGestureRecognizer
    }
  }
}
