import OpenDivingKit
import SwiftUI
import UIKit

/// The round button held at a list's bottom right that adds to it: its symbol white on its fill,
/// a step larger than the top bar's buttons so it reads as the page's main action.
struct FloatingAddButton: View {
  static let side = 56.0
  /// Where the screen's corner is square, or its radius is unknown: inside the safe area.
  static let bottomInset = 16.0
  static let trailingInset = 32.0

  let title: String
  let icon: Icon
  let fill: Color
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Image(icon)
        .font(.system(size: 26))
        .foregroundStyle(.white)
        .frame(width: Self.side, height: Self.side)
        .contentShape(Circle())
        .pickerControl(in: Circle(), tint: fill)
        .shadow(color: .black.opacity(0.18), radius: 6, y: 3)
    }
    .buttonStyle(.plain)
    .accessibilityLabel(title)
  }
}

extension View {
  /// Holds a `FloatingAddButton` at the bottom right, over what scrolls under it, concentric with
  /// the screen's rounded corner where it has one.
  func floatingAddButton(
    _ title: String, icon: Icon, fill: Color, isShown: Bool = true,
    action: @escaping () -> Void
  ) -> some View {
    modifier(
      FloatingAddButtonPlacement(
        button: FloatingAddButton(title: title, icon: icon, fill: fill, action: action),
        isShown: isShown))
  }
}

private struct FloatingAddButtonPlacement: ViewModifier {
  let button: FloatingAddButton
  let isShown: Bool
  @State private var screenCorner = 0.0

  /// From both screen edges, so the button's circle shares the corner's centre. A corner too
  /// tight to leave a gap round the button falls back to the safe area's insets.
  private var concentricInset: Double? {
    let inset = screenCorner - FloatingAddButton.side / 2
    return inset >= 12 ? inset : nil
  }

  func body(content: Content) -> some View {
    content
      .background {
        ScreenCornerProbe(radius: $screenCorner)
          .ignoresSafeArea()
          .allowsHitTesting(false)
          .accessibilityHidden(true)
      }
      .overlay(alignment: .bottomTrailing) {
        if isShown {
          if let inset = concentricInset {
            button
              .padding([.trailing, .bottom], inset)
              .ignoresSafeArea(edges: [.trailing, .bottom])
          } else {
            button
              .padding(.trailing, FloatingAddButton.trailingInset)
              .padding(.bottom, FloatingAddButton.bottomInset)
          }
        }
      }
  }
}

/// The screen's corner radius, which iOS 26 gives as the radius concentric with the window for a
/// view filling it; nothing before, where the button keeps to the safe area.
private struct ScreenCornerProbe: UIViewRepresentable {
  @Binding var radius: Double

  func makeUIView(context: Context) -> UIView {
    guard #available(iOS 26, *) else { return UIView() }
    let view = ProbeView()
    view.onRadius = { value in
      // Out of the layout pass that reports it.
      Task { @MainActor in
        if radius != value { radius = value }
      }
    }
    return view
  }

  func updateUIView(_ uiView: UIView, context: Context) {}

  @available(iOS 26, *)
  private final class ProbeView: UIView {
    var onRadius: ((Double) -> Void)?

    override init(frame: CGRect) {
      super.init(frame: frame)
      isUserInteractionEnabled = false
      cornerConfiguration = .uniformCorners(radius: .containerConcentric())
    }

    required init?(coder: NSCoder) { nil }

    override func layoutSubviews() {
      super.layoutSubviews()
      onRadius?(effectiveRadius(corner: .bottomRight))
    }
  }
}

#Preview {
  ScrollView {
    Color.cardFill.frame(height: 1200)
  }
  .floatingAddButton("Log a dive", icon: .divePlus, fill: .brandCoral) {}
}
