import OpenDivingKit
import SwiftUI

/// The Commons mark in the foreground style, whose bubbles slide and resize into the crossing
/// spinner while `isLoading` and settle back into the mark after. Still under Reduce Motion,
/// where it is the mark or the spinner's first frame.
struct CommonsLoadingMark: View {
  let isLoading: Bool
  @ScaledMetric(relativeTo: .body) private var side = 22.0
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  /// When the spinner's motion began, which it carries on from while it turns back into the mark.
  @State private var spinStart = Date.now
  @State private var changedAt = Date.distantPast
  @State private var blendAtChange = 0.0
  /// The blend has reached the mark or the spinner since `isLoading` last changed.
  @State private var isSettled = true

  var body: some View {
    TimelineView(.animation(paused: reduceMotion || (isSettled && !isLoading))) { timeline in
      let blend = reduceMotion ? (isLoading ? 1 : 0) : blend(at: timeline.date, loading: isLoading)
      let elapsed = reduceMotion ? 0 : timeline.date.timeIntervalSince(spinStart)
      Canvas { context, size in
        let scale = min(size.width, size.height) / 24
        context.translateBy(x: size.width / 2, y: size.height / 2)
        context.scaleBy(x: scale, y: scale)
        for (index, (centre, radius)) in CommonsBubbles.frame(elapsed: elapsed, blend: blend)
          .enumerated()
        {
          let bubble = Path(
            ellipseIn: CGRect(
              x: centre.x - radius, y: centre.y - radius, width: radius * 2, height: radius * 2))
          if index == 0 { context.fill(bubble, with: .style(.foreground)) }
          context.stroke(bubble, with: .style(.foreground), lineWidth: CrossingBubbles.stroke)
        }
      }
    }
    .frame(width: side, height: side)
    .accessibilityHidden(true)
    .onChange(of: isLoading) { wasLoading, loading in
      let now = Date.now
      let from = blend(at: now, loading: wasLoading)
      if loading && from == 0 { spinStart = now }
      blendAtChange = from
      changedAt = now
      isSettled = false
    }
    .task(id: isLoading) {
      try? await Task.sleep(for: .seconds(CommonsBubbles.morph))
      if !Task.isCancelled { isSettled = true }
    }
  }

  private func blend(at date: Date, loading: Bool) -> Double {
    CommonsBubbles.blend(
      from: blendAtChange, loading: loading,
      since: date.timeIntervalSince(changedAt))
  }
}

#Preview {
  @Previewable @State var isLoading = false
  VStack(spacing: 24) {
    CommonsLoadingMark(isLoading: isLoading)
    Toggle("Loading", isOn: $isLoading).fixedSize()
  }
  .padding()
}
