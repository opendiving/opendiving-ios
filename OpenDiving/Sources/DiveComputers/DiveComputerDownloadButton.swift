import OpenDivingKit
import SwiftUI

/// The Dives tab's dive-computer button, which opens the *Dive computer* screen. Over a download
/// the diver left running, the icon's bars rise in a loop inside a ring of its progress.
struct DiveComputerDownloadButton: View {
  let action: () -> Void

  @Environment(DiveComputerDownloads.self) private var downloads

  var body: some View {
    DiveComputerDownloadButtonLabel(content: downloads.button, action: action)
  }
}

/// The button over plain values, which a preview or a test draws in each state: coral while the
/// download runs, teal once it ends well, red when it does not.
struct DiveComputerDownloadButtonLabel: View {
  let content: DiveComputerButtonContent?
  let action: () -> Void

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  /// #FF7F50, the brand's coral.
  private static let coral = Color(red: 1, green: 127 / 255, blue: 80 / 255)
  private static let ringWidth: CGFloat = 2.5

  var body: some View {
    Button(action: action) {
      ZStack {
        if let content {
          Circle()
            .stroke(ringColor(content).opacity(0.2), lineWidth: Self.ringWidth)
          ring(content)
        }
        DiveComputerGlyph(animated: content?.state == .working && !reduceMotion)
          .frame(width: 20, height: 20)
      }
      .frame(width: 32, height: 32)
      .animation(.easeOut(duration: 0.2), value: content == nil)
    }
    .accessibilityLabel(DiveComputerText.connect)
    .accessibilityValue(content?.accessibilityValue ?? "")
  }

  private func ringColor(_ content: DiveComputerButtonContent) -> Color {
    switch content.state {
    case .working, .waiting: Self.coral
    case .succeeded: .teal
    case .failed: .red
    }
  }

  @ViewBuilder private func ring(_ content: DiveComputerButtonContent) -> some View {
    let color = ringColor(content)
    switch content.ring {
    case .fraction(let fraction):
      arc(to: fraction, color)
        .animation(.easeOut(duration: 0.3), value: fraction)
    case .indeterminate:
      TimelineView(.animation(paused: reduceMotion)) { timeline in
        let turn = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1)
        arc(to: 0.25, color)
          .rotationEffect(.degrees(turn * 360))
      }
    }
  }

  private func arc(to fraction: Double, _ color: Color) -> some View {
    Circle()
      .trim(from: 0, to: fraction)
      .stroke(color, style: StrokeStyle(lineWidth: Self.ringWidth, lineCap: .round))
      .rotationEffect(.degrees(-90))
  }
}

#Preview {
  NavigationStack {
    Text("Dives")
      .toolbar {
        ToolbarItemGroup(placement: .topBarLeading) {
          DiveComputerDownloadButtonLabel(content: nil) {}
          DiveComputerDownloadButtonLabel(
            content: .init(ring: .fraction(0.4), state: .working, accessibilityValue: "")
          ) {}
          DiveComputerDownloadButtonLabel(
            content: .init(ring: .fraction(1), state: .succeeded, accessibilityValue: "")
          ) {}
          DiveComputerDownloadButtonLabel(
            content: .init(ring: .fraction(1), state: .failed, accessibilityValue: "")
          ) {}
        }
      }
  }
}
