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
  /// tap on the open row closes it. VoiceOver reaches none of them, so each is in the row's
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
      .offset(x: offset)
      .background(alignment: .leading) { buttons(leading, width: max(offset, 0)) }
      .background(alignment: .trailing) { buttons(trailing, width: max(-offset, 0)) }
      .gesture(
        HorizontalPan(onBegan: { start = offset }, onChanged: moved, onEnded: ended))
  }

  private func width(_ actions: [RowSwipeAction]) -> CGFloat {
    CGFloat(actions.count) * buttonWidth
  }

  /// Follows the finger, a third as far past the buttons' width; nowhere toward a side with none.
  private func moved(_ translation: CGFloat) {
    let raw = start + translation
    let limit = width(raw > 0 ? leading : trailing)
    guard limit > 0 else {
      offset = 0
      return
    }
    let distance = abs(raw)
    let damped = distance > limit ? limit + (distance - limit) / 3 : distance
    offset = raw > 0 ? damped : -damped
  }

  /// Opens the side past half its buttons' width or flung toward, and closes otherwise.
  private func ended(_ velocity: CGFloat) {
    let fling: CGFloat = 500
    if offset > 0, velocity > -fling, offset > width(leading) / 2 || velocity > fling {
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
/// the page's scroll, and only once the navigation's edge swipe back has let the touch go.
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
    func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
      guard let pan = recognizer as? UIPanGestureRecognizer else { return false }
      let velocity = pan.velocity(in: pan.view)
      return abs(velocity.x) > abs(velocity.y)
    }

    func gestureRecognizer(
      _ recognizer: UIGestureRecognizer,
      shouldRequireFailureOf other: UIGestureRecognizer
    ) -> Bool {
      other is UIScreenEdgePanGestureRecognizer
    }
  }
}
