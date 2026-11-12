import OpenDivingKit
import SwiftUI

/// The profile's dive-computer button, which opens the *Dive Computers* screen. Over a
/// download the diver left running, the icon's bars rise in a loop inside a ring of its progress.
struct DiveComputerToolbarItem: ToolbarContent {
  let action: () -> Void

  var body: some ToolbarContent {
    // In the bar's own glass: a glass of its own, with the bar's hidden, is carried on iOS 26
    // into the back button of the page it opens, as a square around its chevron.
    ToolbarItem(placement: .topBarLeading) {
      DiveComputerDownloadButton(action: action)
    }
  }
}

private struct DiveComputerDownloadButton: View {
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

  private static let ringWidth: CGFloat = 2.5
  /// The toolbar's circular buttons, the `+` among them.
  private static let size: CGFloat = MapRoundButtonStyle.side

  /// The label, which the ring overlays on the button's edge. From iOS 26 the bar's glass pads the
  /// label 10 a side across to a circle of `size`: measured, as the system does not name it.
  /// Before, the bar draws no glass and the label is the whole button.
  private static var label: CGSize {
    if #available(iOS 26, *) {
      CGSize(width: 24, height: 30)
    } else {
      CGSize(width: size, height: size)
    }
  }

  var body: some View {
    Button(action: action) {
      // The size of the bar's own symbols: the `+` stands as tall.
      DiveComputerGlyph(animated: content?.state == .working && !reduceMotion)
        .frame(width: 22, height: 22)
        .foregroundStyle(Color.primary)
        .frame(width: Self.label.width, height: Self.label.height)
        .overlay {
          if let content {
            ZStack {
              Circle()
                .stroke(ringColor(content).opacity(0.2), lineWidth: Self.ringWidth)
              ring(content)
            }
            // Its stroke inside its side.
            .padding(Self.ringWidth / 2)
            .frame(width: Self.size, height: Self.size)
            .barItemOverflow()
          }
        }
        .animation(.easeOut(duration: 0.2), value: content == nil)
    }
    .accessibilityLabel(DiveComputerText.connect)
    .accessibilityValue(content?.accessibilityValue ?? "")
  }

  private func ringColor(_ content: DiveComputerButtonContent) -> Color {
    switch content.state {
    case .working, .waiting: Color.brandCoral
    case .succeeded: .brandTeal
    case .failed: .danger
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
    Text("Profile")
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
