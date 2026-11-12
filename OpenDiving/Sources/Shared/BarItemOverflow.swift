import SwiftUI
import UIKit

extension View {
  /// Lets a toolbar item's label draw past the box the bar holds it in, as far as the bar's glass.
  /// iOS 26 cuts an item off at that box, about 36 points square, and sets the cut again after
  /// it lays the bar out; before, the bar has no box, and iOS 27 does not cut.
  @ViewBuilder func barItemOverflow() -> some View {
    if #available(iOS 27, *) {
      self
    } else if #available(iOS 26, *) {
      background(BarItemOverflow())
    } else {
      self
    }
  }
}

private struct BarItemOverflow: UIViewRepresentable {
  func makeUIView(context: Context) -> Keeper {
    let keeper = Keeper()
    keeper.isUserInteractionEnabled = false
    return keeper
  }
  func updateUIView(_ view: Keeper, context: Context) {}

  /// Switches the cut off in each box smaller than the bar's glass between itself and the
  /// navigation bar, and again whenever the bar switches it back on.
  final class Keeper: UIView {
    private var watches: [NSKeyValueObservation] = []

    override func didMoveToWindow() {
      super.didMoveToWindow()
      watches = []
      guard window != nil else { return }
      let side = MapRoundButtonStyle.side
      let boxes = sequence(first: self as UIView) { $0.superview }
        .dropFirst()
        .prefix { !($0 is UINavigationBar) }
      // The glass itself, `side` across, keeps its round cut.
      for box in boxes where box.bounds.width < side || box.bounds.height < side {
        box.clipsToBounds = false
        watches.append(
          box.observe(\.clipsToBounds, options: [.new]) { box, change in
            guard change.newValue == true else { return }
            MainActor.assumeIsolated { box.clipsToBounds = false }
          })
      }
    }
  }
}
