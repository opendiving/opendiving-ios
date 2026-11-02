import OpenDivingKit
import SwiftUI

/// The round button: the dive-computer icon inside a ring of the download's progress, coral
/// while it runs, green once it ends well, red when it does not.
struct DiveComputerDownloadButton: View {
  let content: DiveComputerButtonContent
  let action: () -> Void

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  /// #FF7F50, the brand's coral.
  private static let coral = Color(red: 1, green: 127 / 255, blue: 80 / 255)
  private static let ringWidth: CGFloat = 4

  var body: some View {
    Button(action: action) {
      ZStack {
        Circle().fill(.regularMaterial)
        Circle()
          .stroke(ringColor.opacity(0.2), lineWidth: Self.ringWidth)
          .padding(Self.ringWidth / 2)
        ring
          .padding(Self.ringWidth / 2)
        DiveComputerGlyph(animated: content.state == .working && !reduceMotion)
          .frame(width: 30, height: 30)
          .foregroundStyle(.primary)
      }
      .frame(width: 56, height: 56)
      .shadow(color: .black.opacity(0.2), radius: 6, y: 2)
      .contentShape(Circle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(DiveComputerButtonContent.accessibilityLabel)
    .accessibilityValue(content.accessibilityValue)
    .accessibilityHint(DiveComputerButtonContent.accessibilityHint)
  }

  private var ringColor: Color {
    switch content.state {
    case .working, .waiting: Self.coral
    case .succeeded: .green
    case .failed: .red
    }
  }

  @ViewBuilder private var ring: some View {
    switch content.ring {
    case .fraction(let fraction):
      arc(to: fraction)
        .animation(.easeOut(duration: 0.3), value: fraction)
    case .indeterminate:
      TimelineView(.animation(paused: reduceMotion)) { timeline in
        let turn = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1)
        arc(to: 0.25)
          .rotationEffect(.degrees(turn * 360))
      }
    }
  }

  private func arc(to fraction: Double) -> some View {
    Circle()
      .trim(from: 0, to: fraction)
      .stroke(ringColor, style: StrokeStyle(lineWidth: Self.ringWidth, lineCap: .round))
      .rotationEffect(.degrees(-90))
  }
}

#Preview {
  HStack(spacing: 16) {
    DiveComputerDownloadButton(
      content: .init(ring: .indeterminate, state: .working, accessibilityValue: "")
    ) {}
    DiveComputerDownloadButton(
      content: .init(ring: .fraction(0.4), state: .working, accessibilityValue: "")
    ) {}
    DiveComputerDownloadButton(
      content: .init(ring: .fraction(1), state: .succeeded, accessibilityValue: "")
    ) {}
    DiveComputerDownloadButton(
      content: .init(ring: .fraction(1), state: .failed, accessibilityValue: "")
    ) {}
  }
  .padding()
}
