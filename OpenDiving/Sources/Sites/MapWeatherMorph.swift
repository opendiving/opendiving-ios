import Observation
import SwiftUI

/// Where the weather bar's growth into its card stands: 0 the bar, 1 the card. A tap animates it;
/// a finger drives it, pulling the bar down or pushing the card up, and on letting go it carries on
/// the way it was going, or back the way a flick sends it. The bar and the card share it, since a
/// pull starts on the one and ends in the other.
///
/// The presentation takes a moment to come up and lay itself out, and a finger moves on meanwhile:
/// until it stands in for the bar the progress holds at the bar, then catches up to the finger, so
/// nothing is ever drawn jumping to where the finger already is.
@MainActor
@Observable
final class MapWeatherMorph {
  /// Whether the card's presentation is up, from the first touch on the bar to the end of closing.
  var isPresented = false
  private(set) var progress: CGFloat = 0
  /// Whether the presentation has laid the bar's copy where the bar is, so the bar can step aside
  /// and the progress can move.
  var coversBar = false {
    didSet {
      guard coversBar, !oldValue else { return }
      if let end = waitingEnd {
        settle(at: end)
      } else if isDriven {
        withAnimation(Self.following) { progress = pulled }
      }
    }
  }
  /// How far a finger travels for the whole of it, from the bar to the card's middle.
  var distance: CGFloat = 250
  var animation: Animation = .spring(duration: 0.45, bounce: 0.15)
  /// A finger is driving the progress.
  private var isDriven = false
  /// Where the finger has put the progress, which it shows once the presentation can.
  private var pulled: CGFloat = 0
  /// Where the progress settles once the presentation can show it moving there.
  private var waitingEnd: CGFloat?

  /// Tight enough to stay under the finger, loose enough to smooth its steps.
  private static let following = Animation.interactiveSpring(response: 0.15, dampingFraction: 0.86)

  /// The whole way, animated: a tap.
  func open() {
    isDriven = false
    present()
    settle(at: 1)
  }

  func close() {
    isDriven = false
    settle(at: 0)
  }

  /// A finger on the bar, pulled down by `drag` points: the presentation comes up at the touch,
  /// before the finger has moved, so it is ready to follow it.
  func pull(_ drag: CGFloat) {
    present()
    isDriven = true
    pulled = Self.clamped(drag / distance)
    guard coversBar else { return }
    withAnimation(Self.following) { progress = pulled }
  }

  /// The finger off the bar, its pull heading for `predicted`; also a pull the system cut short,
  /// which carries on.
  func pullEnded(predicted: CGFloat? = nil) {
    guard isDriven else { return }
    isDriven = false
    let heading = predicted.map { Self.clamped($0 / distance) } ?? pulled
    settle(at: heading > pulled || (heading == pulled && pulled > 0) ? 1 : 0)
  }

  /// A finger pushing the open card up by `drag` points, up negative.
  func push(_ drag: CGFloat) {
    isDriven = true
    pulled = Self.clamped(1 + drag / distance)
    withAnimation(Self.following) { progress = pulled }
  }

  func pushEnded(predicted: CGFloat) {
    guard isDriven else { return }
    isDriven = false
    let heading = Self.clamped(1 + predicted / distance)
    settle(at: heading < pulled || (heading == pulled && pulled < 1) ? 0 : 1)
  }

  /// Ends the presentation at once, with nothing animated and whatever was driving it dropped: for
  /// when the weather it shows is gone.
  func dismiss() {
    Self.present {
      isDriven = false
      waitingEnd = nil
      pulled = 0
      progress = 0
      coversBar = false
      isPresented = false
    }
  }

  private func present() {
    guard !isPresented else { return }
    progress = 0
    pulled = 0
    Self.present { isPresented = true }
  }

  private func settle(at end: CGFloat) {
    guard coversBar else {
      waitingEnd = end
      return
    }
    waitingEnd = nil
    pulled = end
    withAnimation(animation) {
      progress = end
    } completion: { [weak self] in
      guard let self, end == 0, progress == 0, !isDriven, waitingEnd == nil else { return }
      coversBar = false
      Self.present { self.isPresented = false }
    }
  }

  private static func clamped(_ value: CGFloat) -> CGFloat {
    min(max(value, 0), 1)
  }

  /// Shows or ends the presentation without its own slide, which would carry the bar away: the
  /// presentation animates what moves.
  static func present(_ change: () -> Void) {
    var transaction = Transaction()
    transaction.disablesAnimations = true
    withTransaction(transaction, change)
  }
}
