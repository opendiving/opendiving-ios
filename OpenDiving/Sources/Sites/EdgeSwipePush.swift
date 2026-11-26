import SwiftUI
import UIKit

/// A swipe in from the screen's right edge that pushes a page under the finger, as the system's
/// back swipe from the left edge pops one. `push` asks for the page, which then follows the
/// finger; let go past halfway or moving left and it lands, short of it or moving right and it
/// slides back out, and `cancelled` says so. Every other pan waits for the swipe to fail, which it
/// does as soon as a touch lands away from the edge, so the map and the panel move only for a
/// swipe that is not this one.
struct EdgeSwipePush: UIGestureRecognizerRepresentable {
  var isEnabled = true
  let push: () -> Void
  let cancelled: () -> Void

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
    let width = max(recognizer.view?.window?.bounds.width ?? 1, 1)
    let travelled = -recognizer.translation(in: nil).x / width
    switch recognizer.state {
    case .began:
      guard let navigation = recognizer.view?.enclosingNavigationController else { return }
      context.coordinator.push = EdgePush(navigation: navigation, cancelled: cancelled)
      push()
    case .changed:
      context.coordinator.push?.follow(travelled)
    case .ended:
      let speed = recognizer.velocity(in: nil).x
      context.coordinator.push?.release(lands: speed < -300 || (travelled > 0.5 && speed < 300))
      context.coordinator.push = nil
    case .cancelled, .failed:
      context.coordinator.push?.release(lands: false)
      context.coordinator.push = nil
    default:
      break
    }
  }

  final class Coordinator: NSObject, UIGestureRecognizerDelegate {
    fileprivate var push: EdgePush?

    func gestureRecognizer(
      _ recognizer: UIGestureRecognizer,
      shouldBeRequiredToFailBy other: UIGestureRecognizer
    ) -> Bool {
      other is UIPanGestureRecognizer
    }
  }
}

extension UIView {
  fileprivate var enclosingNavigationController: UINavigationController? {
    sequence(first: self as UIResponder, next: \.next)
      .lazy.compactMap { ($0 as? UIViewController)?.navigationController }.first
  }
}

/// One swipe's push. A navigation stack offers no interactive push, so for the length of it this
/// stands in as the navigation controller's delegate, answering the push with an animation the
/// finger drives and handing everything else to the delegate it stood in for, SwiftUI's, which
/// it puts back once the page has landed or slid back out.
@MainActor
private final class EdgePush: UIPercentDrivenInteractiveTransition, UINavigationControllerDelegate {
  private weak var navigation: UINavigationController?
  /// Read from the runtime's forwarding, which is not isolated; set once, before this is the
  /// delegate, and only ever read.
  nonisolated(unsafe) private let original: (any UINavigationControllerDelegate)?
  private let animator = EdgePushAnimator()
  private let cancelled: () -> Void
  /// The navigation controller holds its delegate weakly; this holds the stand-in until it is
  /// taken down.
  private var standingIn: EdgePush?
  private var travelled = 0.0
  private var hasStarted = false
  /// How the swipe ended, when it ended before the stack began the push.
  private var released: Bool?

  init(navigation: UINavigationController, cancelled: @escaping () -> Void) {
    self.navigation = navigation
    original = navigation.delegate
    self.cancelled = cancelled
    super.init()
    completionCurve = .easeOut
    animator.ended = { [weak self] landed in
      if !landed { self?.cancelled() }
      self?.standDown()
    }
    standingIn = self
    navigation.delegate = self
  }

  func follow(_ travelled: Double) {
    self.travelled = min(max(travelled, 0), 1)
    if hasStarted { update(self.travelled) }
  }

  func release(lands: Bool) {
    guard hasStarted else {
      released = lands
      return
    }
    lands ? finish() : cancel()
  }

  override func startInteractiveTransition(
    _ transitionContext: any UIViewControllerContextTransitioning
  ) {
    super.startInteractiveTransition(transitionContext)
    hasStarted = true
    update(travelled)
    if let released { released ? finish() : cancel() }
  }

  func navigationController(
    _ navigationController: UINavigationController,
    animationControllerFor operation: UINavigationController.Operation,
    from: UIViewController, to: UIViewController
  ) -> (any UIViewControllerAnimatedTransitioning)? {
    guard operation == .push else {
      return original?.navigationController?(
        navigationController, animationControllerFor: operation, from: from, to: to)
    }
    return animator
  }

  func navigationController(
    _ navigationController: UINavigationController,
    interactionControllerFor animationController: any UIViewControllerAnimatedTransitioning
  ) -> (any UIViewControllerInteractiveTransitioning)? {
    guard animationController === animator else {
      return original?.navigationController?(
        navigationController, interactionControllerFor: animationController)
    }
    return self
  }

  private func standDown() {
    if navigation?.delegate === self { navigation?.delegate = original }
    standingIn = nil
  }

  override nonisolated func responds(to selector: Selector!) -> Bool {
    super.responds(to: selector) || (original?.responds(to: selector) ?? false)
  }

  override nonisolated func forwardingTarget(for selector: Selector!) -> Any? {
    original
  }
}

/// The push as the system draws it: the page slides in from the right over the one it covers,
/// which drifts a third of the way left and dims.
@MainActor
private final class EdgePushAnimator: NSObject, UIViewControllerAnimatedTransitioning {
  /// Whether the page landed, once it has or has slid back out.
  var ended: (Bool) -> Void = { _ in }
  private var running: UIViewPropertyAnimator?

  func transitionDuration(using context: (any UIViewControllerContextTransitioning)?)
    -> TimeInterval
  { 0.35 }

  func animateTransition(using context: any UIViewControllerContextTransitioning) {
    interruptibleAnimator(using: context).startAnimation()
  }

  func interruptibleAnimator(using context: any UIViewControllerContextTransitioning)
    -> any UIViewImplicitlyAnimating
  {
    if let running { return running }
    let container = context.containerView
    let width = container.bounds.width
    let toController = context.viewController(forKey: .to)
    let from = context.view(forKey: .from) ?? context.viewController(forKey: .from)?.view
    let to = context.view(forKey: .to) ?? toController?.view
    let dim = UIView(frame: container.bounds)
    dim.backgroundColor = .black.withAlphaComponent(0.1)
    dim.alpha = 0
    container.addSubview(dim)
    if let to {
      if let toController { to.frame = context.finalFrame(for: toController) }
      container.addSubview(to)
      to.transform = CGAffineTransform(translationX: width, y: 0)
    }
    let animator = UIViewPropertyAnimator(
      duration: transitionDuration(using: context), curve: .linear
    ) {
      to?.transform = .identity
      from?.transform = CGAffineTransform(translationX: -width / 3, y: 0)
      dim.alpha = 1
    }
    animator.addCompletion { [weak self] _ in
      let landed = !context.transitionWasCancelled
      from?.transform = .identity
      to?.transform = .identity
      dim.removeFromSuperview()
      if !landed { to?.removeFromSuperview() }
      context.completeTransition(landed)
      self?.running = nil
      self?.ended(landed)
    }
    running = animator
    return animator
  }
}
