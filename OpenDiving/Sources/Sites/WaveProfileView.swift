import OpenDivingKit
import SwiftUI

/// The waves and the swell as the sea's surface passing, a strip each on one height scale between
/// its label and its value: the surface's line over a fill that fades as the tide's does, in front
/// of a fainter row. VoiceOver reads it as one sentence.
struct WaveProfileView: View {
  let profile: WaveProfile

  var body: some View {
    Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 6) {
      ForEach(profile.strips, id: \.label) { strip in
        GridRow {
          Text(strip.label)
            .foregroundStyle(.secondary)
          Canvas { context, size in
            Self.draw(strip, in: &context, size: size)
          }
          .frame(height: 28)
          Text(strip.value)
            .monospacedDigit()
            .gridColumnAlignment(.trailing)
        }
      }
    }
    .font(.subheadline)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(profile.accessibilityLabel)
  }

  private static func draw(
    _ strip: WaveProfile.Strip, in context: inout GraphicsContext, size: CGSize
  ) {
    func line(_ points: [CurvePoint]) -> Path {
      Path { path in
        path.addLines(points.map { CGPoint(x: $0.x * size.width, y: $0.y * size.height) })
      }
    }
    func water(_ points: [CurvePoint]) -> Path {
      var water = line(points)
      water.addLine(to: CGPoint(x: size.width, y: size.height))
      water.addLine(to: CGPoint(x: 0, y: size.height))
      water.closeSubpath()
      return water
    }

    context.fill(water(strip.behind), with: .color(Color.brandTeal.opacity(0.12)))
    let surface = line(strip.surface)
    context.fill(
      water(strip.surface),
      with: .linearGradient(
        Gradient(colors: [Color.brandTeal.opacity(0.3), Color.brandTeal.opacity(0)]),
        startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
    context.stroke(
      surface, with: .color(.brandTeal),
      style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
  }
}

#Preview {
  if let profile = WaveProfile(
    ConditionsSea(waveHeight: 0.94, wavePeriod: 3.7, swellWaveHeight: 0.1), units: .metric)
  {
    WaveProfileView(profile: profile)
      .padding()
      .frame(width: 320)
  }
}
