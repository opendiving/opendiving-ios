import OpenDivingKit
import SwiftUI

/// The tide from its last turn to its next, as the web's dive page draws it: the curve over a fill
/// that fades downward, fainter past the turns, a dot at the hour shown, and each turn's time under
/// it. VoiceOver reads it as one sentence.
struct TideCurveView: View {
  let curve: TideCurve

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("Tide")
        .foregroundStyle(.secondary)
      Canvas { context, size in
        draw(in: &context, size: size)
      }
      .frame(height: 48)
      GeometryReader { geometry in
        ForEach(curve.turns, id: \.x) { turn in
          HStack(spacing: 4) {
            Text(turn.label)
              .foregroundStyle(.secondary)
            Text(turn.clock)
              .fontWeight(.medium)
              .monospacedDigit()
          }
          .fixedSize()
          .position(x: turn.x * geometry.size.width, y: geometry.size.height / 2)
        }
      }
      .frame(height: 16)
    }
    .font(.caption)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(curve.accessibilityLabel)
  }

  private func draw(in context: inout GraphicsContext, size: CGSize) {
    func place(_ point: TideCurve.Point) -> CGPoint {
      CGPoint(x: point.x * size.width, y: point.y * size.height)
    }
    func line(_ points: [TideCurve.Point]) -> Path {
      Path { path in path.addLines(points.map(place)) }
    }

    var area = line(curve.before + curve.between.dropFirst() + curve.after.dropFirst())
    area.addLine(to: CGPoint(x: size.width, y: size.height))
    area.addLine(to: CGPoint(x: 0, y: size.height))
    area.closeSubpath()
    context.fill(
      area,
      with: .linearGradient(
        Gradient(colors: [Color.brandTeal.opacity(0.3), Color.brandTeal.opacity(0)]),
        startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))

    let stroke = StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
    for (points, opacity) in [(curve.before, 0.35), (curve.between, 1), (curve.after, 0.35)] {
      context.stroke(line(points), with: .color(Color.brandTeal.opacity(opacity)), style: stroke)
    }

    if let now = curve.now {
      let centre = place(now)
      // A ring of the background around the dot, so it reads over the line it sits on.
      context.fill(Circle().path(in: square(centre, side: 14)), with: .style(.background))
      context.fill(Circle().path(in: square(centre, side: 10)), with: .style(.primary))
    }
  }

  private func square(_ centre: CGPoint, side: CGFloat) -> CGRect {
    CGRect(x: centre.x - side / 2, y: centre.y - side / 2, width: side, height: side)
  }
}

#Preview {
  if let curve = TideCurve(
    previous: ConditionsExtreme(
      kind: "high", at: DiveTimestamp(wireValue: "2026-11-10T18:00:00+02:00")!, height: 0.33),
    next: ConditionsExtreme(
      kind: "low", at: DiveTimestamp(wireValue: "2026-11-11T01:00:00+02:00")!, height: -0.27),
    now: DiveTimestamp(wireValue: "2026-11-10T19:00:00+02:00"), state: "falling")
  {
    TideCurveView(curve: curve)
      .padding()
      .frame(width: 320)
  }
}
