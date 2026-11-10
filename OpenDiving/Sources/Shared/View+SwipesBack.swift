import SwiftUI
import UIKit

extension View {
  /// Lets a page that hides the system back button for one of its own still be swiped back from
  /// the screen's edge, which hiding the button turns off.
  func swipesBackWithoutBackButton() -> some View {
    background(SwipeBack())
  }
}

/// Answers the navigation controller's edge swipe while the page is on top, and hands it back to
/// the system's own answer before anything is pushed over the page or the page leaves.
private struct SwipeBack: UIViewControllerRepresentable {
  func makeUIViewController(context: Context) -> Controller { Controller() }
  func updateUIViewController(_ controller: Controller, context: Context) {}

  final class Controller: UIViewController, UIGestureRecognizerDelegate {
    private weak var systemDelegate: (any UIGestureRecognizerDelegate)?

    override func viewDidAppear(_ animated: Bool) {
      super.viewDidAppear(animated)
      guard let pop = navigationController?.interactivePopGestureRecognizer, pop.delegate !== self
      else { return }
      systemDelegate = pop.delegate
      pop.delegate = self
    }

    override func viewWillDisappear(_ animated: Bool) {
      super.viewWillDisappear(animated)
      guard let pop = navigationController?.interactivePopGestureRecognizer, pop.delegate === self
      else { return }
      pop.delegate = systemDelegate
    }

    func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
      (navigationController?.viewControllers.count ?? 0) > 1
    }
  }
}
