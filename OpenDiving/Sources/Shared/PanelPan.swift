import SwiftUI
import UIKit

/// A pan that moves a panel by the part of it outside its list, the handle and the search. It is
/// UIKit's pan rather than a drag gesture because that one says when the system takes the touch
/// away, which would otherwise leave the panel where the finger last had it, and it starts the
/// panel from where the finger was once the pan began rather than jumping the distance that took.
struct PanelPan: UIGestureRecognizerRepresentable {
  var isEnabled = true
  /// The pan's translation since it began, downward positive.
  let onChanged: (Double) -> Void
  /// The speed the finger let go at, in points a second downward, or 0 when the pan was taken.
  let onEnded: (Double) -> Void

  func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
    UIPanGestureRecognizer()
  }

  func updateUIGestureRecognizer(_ recognizer: UIPanGestureRecognizer, context: Context) {
    recognizer.isEnabled = isEnabled
  }

  func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
    switch recognizer.state {
    case .began:
      recognizer.setTranslation(.zero, in: nil)
    case .changed:
      onChanged(Double(recognizer.translation(in: nil).y))
    case .ended:
      onEnded(Double(recognizer.velocity(in: nil).y))
    case .cancelled, .failed:
      onEnded(0)
    default:
      break
    }
  }
}
