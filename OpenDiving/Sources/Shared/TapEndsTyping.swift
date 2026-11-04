import SwiftUI
import UIKit

/// Ends typing on a tap anywhere on the screen it sits in, except in a text box. That covers the
/// controls that open a sheet too: UIKit hands the first responder back when a sheet closes, and
/// the form then scrolls to that box, away from what was picked.
struct TapEndsTyping: UIViewRepresentable {
  func makeUIView(context: Context) -> Anchor { Anchor() }

  func updateUIView(_ uiView: Anchor, context: Context) {}

  /// Hangs the recognizer on its view controller's view, which holds the whole screen and none of
  /// a sheet over it. It lets every touch through, so what was tapped still answers.
  final class Anchor: UIView, UIGestureRecognizerDelegate {
    private lazy var tap: UITapGestureRecognizer = {
      let tap = UITapGestureRecognizer(target: self, action: #selector(tapped))
      tap.cancelsTouchesInView = false
      tap.delegate = self
      return tap
    }()

    override func didMoveToWindow() {
      super.didMoveToWindow()
      tap.view?.removeGestureRecognizer(tap)
      if window != nil { screen?.addGestureRecognizer(tap) }
    }

    private var screen: UIView? {
      var responder: UIResponder? = self
      while let current = responder {
        if let controller = current as? UIViewController { return controller.view }
        responder = current.next
      }
      return nil
    }

    @objc private func tapped() {
      window?.endEditing(true)
    }

    func gestureRecognizer(
      _ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch
    ) -> Bool {
      var view = touch.view
      while let current = view {
        if current is UITextInput { return false }
        view = current.superview
      }
      return true
    }

    func gestureRecognizer(
      _ gestureRecognizer: UIGestureRecognizer,
      shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
    ) -> Bool { true }
  }
}
