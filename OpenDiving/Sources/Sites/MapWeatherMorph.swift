import Observation
import SwiftUI

/// Where the weather bar's growth into its card stands: 0 the bar, 1 the card. A tap animates it;
/// a finger drives it, pulling the bar down or pushing the card up, and on letting go it carries on
/// the way it was going, or back the way a flick sends it. The bar and the card share it, since a
/// pull starts on the one and ends in the other.
@MainActor
@Observable
final class MapWeatherMorph {
  /// Whether the card's presentation is up, from the first sign of opening to the end of closing.
  var isPresented = false
  private(set) var progress: CGFloat = 0
  /// Whether the presentation has laid the bar's copy where the bar is, so the bar can step aside.
  var coversBar = false
  /// How far a finger travels for the whole of it, from the bar to the card's middle.
  var distance: CGFloat = 250
  var animation: Animation = .spring(duration: 0.45, bounce: 0.15)
  /// A finger is driving the progress, which the presentation then leaves to it on appearing.
  private(set) var isDriven = false

  func open() {
    isDriven = false
    Self.present { isPresented = true }
  }

  /// What the presentation does on appearing for a tap: the whole way, animated.
  func animateOpen() {
    withAnimation(animation) { progress = 1 }
  }

  func close() {
    isDriven = false
    settle(at: 0)
  }

  /// A finger pulling the bar down by `drag` points.
  func pull(_ drag: CGFloat) {
    if !isPresented {
      progress = 0
      isDriven = true
      Self.present { isPresented = true }
    }
    guard isDriven else { return }
    progress = Self.clamped(drag / distance)
  }

  /// The finger off the bar, its pull heading for `predicted`; also a pull the system cut short,
  /// which carries on.
  func pullEnded(predicted: CGFloat? = nil) {
    guard isDriven else { return }
    isDriven = false
    let heading = predicted.map { Self.clamped($0 / distance) } ?? progress
    settle(at: heading > progress || (heading == progress && progress > 0) ? 1 : 0)
  }

  /// A finger pushing the open card up by `drag` points, up negative.
  func push(_ drag: CGFloat) {
    isDriven = true
    progress = Self.clamped(1 + drag / distance)
  }

  func pushEnded(predicted: CGFloat) {
    guard isDriven else { return }
    isDriven = false
    let heading = Self.clamped(1 + predicted / distance)
    settle(at: heading < progress || (heading == progress && progress < 1) ? 0 : 1)
  }

  private func settle(at end: CGFloat) {
    withAnimation(animation) {
      progress = end
    } completion: { [weak self] in
      guard let self, end == 0, progress == 0, !isDriven else { return }
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
