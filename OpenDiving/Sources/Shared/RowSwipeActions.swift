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
  /// Swipe actions on full-height fills that the row slides over, outside a `List` or in one in
  /// place of its own `swipeActions`: a swipe right shows `leading`, a swipe left `trailing`, each
  /// a button that acts and closes the row, and a tap on the open row closes it. A swipe past half the row, and well past its buttons, runs the
  /// side's first as it lets go. VoiceOver reaches none of them, so each belongs in the row's
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
  @State private var isPanning = false
  /// How far the first button's name has travelled from its middle to beside the row.
  @State private var toRow: CGFloat = 0
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
      .modifier(Slide(x: offset))
      .background(alignment: .leading) {
        buttons(leading, side: .leading, width: max(offset, 0))
      }
      .background(alignment: .trailing) {
        buttons(trailing, side: .trailing, width: max(-offset, 0))
      }
      .gesture(
        HorizontalPan(
          onBegan: {
            start = offset
            isPanning = true
          }, onChanged: moved, onEnded: ended)
      )
      // Crossing into a full swipe and back out of it, under the finger: the row settling as it
      // lets go says nothing.
      .sensoryFeedback(.impact, trigger: isFullSwipe) { _, _ in isPanning }
      .onChange(of: isFullSwipe) { _, isFull in
        withAnimation(.smooth(duration: 0.12)) { toRow = isFull ? 1 : 0 }
      }
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
  /// or flung toward, and closes otherwise. A pan taken from the finger only closes.
  private func ended(_ velocity: CGFloat?) {
    isPanning = false
    guard let velocity else { return settle(at: 0) }
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

  /// A side's buttons across `width`, each name in its middle; on a full swipe the first alone,
  /// its name gone beside the row, which it runs if let go there.
  private func buttons(_ actions: [RowSwipeAction], side: HorizontalEdge, width: CGFloat)
    -> some View
  {
    let isFull = isFullSwipe && (side == .leading) == (offset > 0)
    return HStack(spacing: 0) {
      ForEach(Array(actions.enumerated()), id: \.element.id) { index, item in
        if index == 0 || !isFull {
          Button {
            settle(at: 0)
            item.action()
          } label: {
            SlidingName(toRow: index == 0 ? toRow : 0, side: side) {
              VStack(spacing: 4) {
                item.image.font(.title3)
                Text(item.title).font(.caption.weight(.semibold))
              }
              .lineLimit(1)
              .minimumScaleFactor(0.7)
              .foregroundStyle(.white)
              .frame(width: buttonWidth)
            }
            .background(item.fill)
          }
          .buttonStyle(.plain)
        }
      }
    }
    .frame(width: width)
    .clipped()
    .accessibilityHidden(true)
  }
}

/// The row's slide, one transform over all of it worked out at each frame. An `offset` animates
/// each of the row's views on its own, so one the action puts in as the row slides back, a new
/// badge, lands where the row comes to rest ahead of the rest.
private struct Slide: GeometryEffect {
  var x: CGFloat

  var animatableData: CGFloat {
    get { x }
    set { x = newValue }
  }

  func effectValue(size: CGSize) -> ProjectionTransform {
    ProjectionTransform(CGAffineTransform(translationX: x, y: 0))
  }
}

/// A button's name, `toRow` of the way from its middle to the edge beside the row: a layout, so a
/// name on its way there follows the button's width as the finger changes it.
private struct SlidingName: Layout {
  var toRow: CGFloat
  let side: HorizontalEdge

  var animatableData: CGFloat {
    get { toRow }
    set { toRow = newValue }
  }

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    proposal.replacingUnspecifiedDimensions()
  }

  func placeSubviews(
    in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
  ) {
    guard let name = subviews.first else { return }
    let size = name.sizeThatFits(.unspecified)
    let middle = bounds.midX - size.width / 2
    let besideRow = side == .leading ? bounds.maxX - size.width : bounds.minX
    name.place(
      at: CGPoint(x: middle + (besideRow - middle) * toRow, y: bounds.midY - size.height / 2),
      proposal: ProposedViewSize(size))
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
  /// The speed the finger let go at, in points a second rightward, or nil when the pan was taken
  /// from it.
  let onEnded: (CGFloat?) -> Void

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
      onEnded(nil)
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
