import SwiftUI
import UIKit
import UIKit.UIGestureRecognizerSubclass

/// A swipe in from the screen's right edge that pushes a page under the finger, as the system's
/// back swipe from the left edge pops one. `push` asks for the page, which then follows the
/// finger; let go past halfway or moving left and it lands, short of it or moving right and it
/// slides back out, and `cancelled` says so. A touch that lands at the edge holds every other pan
/// until the swipe fails, which it does as soon as the finger goes right or more down than across,
/// so the map and the panel move only for a drag that is not this one; a touch away from the edge
/// never reaches it. Put it in the background of the page it pushes from.
struct EdgeSwipePush: UIViewRepresentable {
  var isEnabled = true
  let push: () -> Void
  let cancelled: () -> Void

  func makeCoordinator() -> Coordinator { Coordinator() }

  func makeUIView(context: Context) -> Anchor {
    let anchor = Anchor()
    anchor.isUserInteractionEnabled = false
    anchor.coordinator = context.coordinator
    return anchor
  }

  func updateUIView(_ anchor: Anchor, context: Context) {
    context.coordinator.isEnabled = isEnabled
    context.coordinator.push = push
    context.coordinator.cancelled = cancelled
  }

  static func dismantleUIView(_ anchor: Anchor, coordinator: Coordinator) {
    coordinator.detach()
  }

  /// Where the page is: in a window while it shows, and the way to its navigation controller.
  final class Anchor: UIView {
    fileprivate weak var coordinator: Coordinator?

    override func didMoveToWindow() {
      super.didMoveToWindow()
      coordinator?.attach(to: self)
    }
  }

  final class Coordinator: NSObject, UIGestureRecognizerDelegate {
    fileprivate var isEnabled = true
    fileprivate var push: () -> Void = {}
    fileprivate var cancelled: () -> Void = {}
    private let recognizer = EdgeDrag()
    private weak var anchor: Anchor?
    private var swipe: EdgePush?

    override init() {
      super.init()
      recognizer.delegate = self
      recognizer.addTarget(self, action: #selector(handle))
    }

    /// On the navigation controller's own view, beside the back swipe's: a gesture SwiftUI holds
    /// waits on the gestures of the views inside it, and the map's would hold the swipe back.
    fileprivate func attach(to anchor: Anchor) {
      self.anchor = anchor
      guard anchor.window != nil, let navigation = anchor.enclosingNavigationController,
        recognizer.view !== navigation.view
      else { return }
      detach()
      navigation.view.addGestureRecognizer(recognizer)
    }

    fileprivate func detach() {
      recognizer.view?.removeGestureRecognizer(recognizer)
    }

    /// The page is the one showing: the navigation controller keeps only the top page in its
    /// window.
    private var isShowing: Bool { isEnabled && anchor?.window != nil }

    func gestureRecognizer(_ recognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool
    {
      guard isShowing, let window = touch.window else { return false }
      return touch.location(in: window).x >= window.bounds.width - Self.edge
    }

    /// How far in from the edge a swipe may start, as far as the system's back swipe reaches.
    private static let edge: CGFloat = 24

    func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
      // A swipe that lands while the last one's page is still sliding would stand in for the
      // stand-in, and leave it the delegate once both were done.
      isShowing && anchor?.enclosingNavigationController?.transitionCoordinator == nil
    }

    func gestureRecognizer(
      _ recognizer: UIGestureRecognizer,
      shouldBeRequiredToFailBy other: UIGestureRecognizer
    ) -> Bool {
      other is UIPanGestureRecognizer
    }

    @objc private func handle(_ recognizer: EdgeDrag) {
      let width = max(recognizer.view?.window?.bounds.width ?? 1, 1)
      let travelled = recognizer.travelled / width
      switch recognizer.state {
      case .began:
        guard let navigation = anchor?.enclosingNavigationController else { return }
        swipe = EdgePush(navigation: navigation, cancelled: cancelled)
        push()
      case .changed:
        swipe?.follow(travelled)
      case .ended:
        let speed = recognizer.speed
        swipe?.release(lands: speed < -300 || (travelled > 0.5 && speed < 300))
        swipe = nil
      case .cancelled, .failed:
        swipe?.release(lands: false)
        swipe = nil
      default:
        break
      }
    }
  }
}

/// One finger dragged left from the edge, begun within its first few points: a pan waits for ten,
/// and a screen-edge pan holds a slow swipe back a fifth of a second. A drag that goes right
/// first, or more down than across, is not this one.
private final class EdgeDrag: UIGestureRecognizer {
  /// How far left of where it began the finger is, in points: what came before it began moves
  /// nothing, as a pan's translation leaves out the distance it waited for.
  private(set) var travelled: CGFloat = 0
  /// How fast the finger moves across, in points a second, negative leftward.
  private(set) var speed: CGFloat = 0
  private var start = CGPoint.zero
  private var last: (x: CGFloat, at: TimeInterval) = (0, 0)

  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
    guard state == .possible, touches.count == 1, let touch = touches.first,
      event.allTouches?.count == 1
    else {
      state = state == .possible ? .failed : .cancelled
      return
    }
    start = touch.location(in: nil)
    last = (start.x, touch.timestamp)
  }

  override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
    guard let touch = touches.first else { return }
    let point = touch.location(in: nil)
    if touch.timestamp > last.at {
      speed = (point.x - last.x) / (touch.timestamp - last.at)
      last = (point.x, touch.timestamp)
    }
    travelled = start.x - point.x
    let down = abs(point.y - start.y)
    switch state {
    case .possible:
      if travelled >= 3, travelled > down {
        start = point
        travelled = 0
        state = .began
      } else if travelled <= -3 || down >= 10 {
        state = .failed
      }
    case .began, .changed: state = .changed
    default: break
    }
  }

  override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
    state = state == .began || state == .changed ? .ended : .failed
  }

  override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
    state = state == .began || state == .changed ? .cancelled : .failed
  }

  override func reset() {
    super.reset()
    travelled = 0
    speed = 0
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
  /// The page the swipe leaves, which drifts under the finger while the stack builds the one it
  /// pushes, as it drifts once the push is under way.
  private weak var leaving: UIView?
  private var travelled = 0.0
  private var hasStarted = false
  /// How far the finger had come when the push began: the page comes in from the edge then, and
  /// moves as far as the finger does after, as the back swipe's page does.
  private var startedAt = 0.0
  /// How the swipe ended, when it ended before the stack began the push.
  private var released: Bool?

  init(navigation: UINavigationController, cancelled: @escaping () -> Void) {
    self.navigation = navigation
    leaving = navigation.topViewController?.view
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
    if hasStarted {
      update(progress)
    } else if let leaving {
      leaving.transform = EdgePushAnimator.drift(self.travelled, width: leaving.bounds.width)
    }
  }

  private var progress: Double { min(max(travelled - startedAt, 0), 1) }

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
    startedAt = travelled
    super.startInteractiveTransition(transitionContext)
    hasStarted = true
    update(progress)
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

  /// Where the covered page stands with the finger `travelled` of the way across.
  static func drift(_ travelled: Double, width: CGFloat) -> CGAffineTransform {
    CGAffineTransform(translationX: -travelled * width / 3, y: 0)
  }

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
      from?.transform = Self.drift(1, width: width)
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
