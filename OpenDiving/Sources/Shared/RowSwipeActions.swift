import SwiftUI
import UIKit

/// One of a row's swipe actions: its name under its symbol, on its fill.
struct RowSwipeAction: Identifiable {
  let title: String
  let image: Image
  let fill: Color
  let action: () -> Void

  var id: String { title }
}

extension View {
  /// Swipe actions for a row outside a `List`, which alone takes `swipeActions`: a swipe right
  /// shows `leading`, a swipe left `trailing`, each a button that acts and closes the row, and a
  /// tap on the open row closes it. A swipe past half the row's width runs the side's first. VoiceOver reaches none of them, so each is in the row's
  /// context menu too.
  func rowSwipeActions(leading: [RowSwipeAction] = [], trailing: [RowSwipeAction] = [])
    -> some View
  {
    modifier(RowSwipeActions(leading: leading, trailing: trailing))
  }
}

private struct RowSwipeActions: ViewModifier {
  let leading: [RowSwipeAction]
  let trailing: [RowSwipeAction]

  @State private var offset: CGFloat = 0
  /// Where the row rested as the pan began.
  @State private var start: CGFloat = 0
  @State private var rowWidth: CGFloat = 0
  @ScaledMetric private var buttonWidth: CGFloat = 76

  func body(content: Content) -> some View {
    content
      .overlay {
        if offset != 0 {
          Color.clear
            .contentShape(.rect)
            .onTapGesture { settle(at: 0) }
        }
      }
      .onGeometryChange(for: CGFloat.self) {
        $0.size.width
      } action: {
        rowWidth = $0
      }
      .offset(x: offset)
      .background(alignment: .leading) { buttons(leading, width: max(offset, 0)) }
      .background(alignment: .trailing) { buttons(trailing, width: max(-offset, 0)) }
      .gesture(
        HorizontalPan(onBegan: { start = offset }, onChanged: moved, onEnded: ended)
      )
      .sensoryFeedback(.impact, trigger: isFullSwipe) { _, isFull in isFull }
  }

  private func width(_ actions: [RowSwipeAction]) -> CGFloat {
    CGFloat(actions.count) * buttonWidth
  }

  /// How far a swipe goes to run its side's first action as it lets go.
  private var fullSwipe: CGFloat {
    max(rowWidth / 2, max(width(leading), width(trailing)) + 24)
  }

  private var isFullSwipe: Bool { abs(offset) >= fullSwipe }

  /// Follows the finger across the row; nowhere toward a side with no actions.
  private func moved(_ translation: CGFloat) {
    let raw = start + translation
    guard width(raw > 0 ? leading : trailing) > 0 else {
      offset = 0
      return
    }
    offset = raw > 0 ? min(raw, rowWidth) : max(raw, -rowWidth)
  }

  /// Runs the side's first action past a full swipe, opens the side past half its buttons' width
  /// or flung toward, and closes otherwise.
  private func ended(_ velocity: CGFloat) {
    let fling: CGFloat = 500
    if isFullSwipe, let first = (offset > 0 ? leading : trailing).first {
      settle(at: 0)
      first.action()
    } else if offset > 0, velocity > -fling, offset > width(leading) / 2 || velocity > fling {
      settle(at: width(leading))
    } else if offset < 0, velocity < fling, -offset > width(trailing) / 2 || velocity < -fling {
      settle(at: -width(trailing))
    } else {
      settle(at: 0)
    }
  }

  private func settle(at target: CGFloat) {
    start = target
    withAnimation(.snappy(duration: 0.25)) { offset = target }
  }

  private func buttons(_ actions: [RowSwipeAction], width: CGFloat) -> some View {
    HStack(spacing: 0) {
      ForEach(actions) { item in
        Button {
          settle(at: 0)
          item.action()
        } label: {
          VStack(spacing: 4) {
            item.image.font(.title3)
            Text(item.title).font(.caption.weight(.semibold))
          }
          .lineLimit(1)
          .minimumScaleFactor(0.7)
          .foregroundStyle(.white)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .background(item.fill)
        }
        .buttonStyle(.plain)
      }
    }
    .frame(width: width)
    .clipped()
    .accessibilityHidden(true)
  }
}

/// UIKit's pan, which begins only on a sideways swipe and so leaves an upward or downward one to
/// the page's scroll. The navigation's swipes back wait for it, as they do for a list's row,
/// both the edge's and the one from anywhere on the page; it leaves them a swipe that starts at
/// the screen's edge.
private struct HorizontalPan: UIGestureRecognizerRepresentable {
  let onBegan: () -> Void
  /// The pan's translation since it began, rightward positive.
  let onChanged: (CGFloat) -> Void
  /// The speed the finger let go at, in points a second rightward, or 0 when the pan was taken.
  let onEnded: (CGFloat) -> Void

  func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator { Coordinator() }

  func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
    let pan = UIPanGestureRecognizer()
    pan.delegate = context.coordinator
    return pan
  }

  func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
    switch recognizer.state {
    case .began:
      recognizer.setTranslation(.zero, in: nil)
      onBegan()
    case .changed:
      onChanged(recognizer.translation(in: nil).x)
    case .ended:
      onEnded(recognizer.velocity(in: nil).x)
    case .cancelled, .failed:
      onEnded(0)
    default:
      break
    }
  }

  final class Coordinator: NSObject, UIGestureRecognizerDelegate {
    /// How far in from the screen's edge a swipe is the edge's swipe back.
    private static let edge: CGFloat = 24

    func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
      guard let pan = recognizer as? UIPanGestureRecognizer else { return false }
      let velocity = pan.velocity(in: pan.view)
      let start = pan.location(in: nil).x - pan.translation(in: nil).x
      return abs(velocity.x) > abs(velocity.y) && start > Self.edge
    }

    func gestureRecognizer(
      _ recognizer: UIGestureRecognizer,
      shouldBeRequiredToFailBy other: UIGestureRecognizer
    ) -> Bool {
      // The swipes back, of either kind: the scroll's pan and another row's are left alone.
      other is UIPanGestureRecognizer && !(other.view is UIScrollView)
        && !(other.delegate is Coordinator)
    }
  }
}
