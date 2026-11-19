import OpenDivingKit
import SwiftUI

/// The round button held at a list's bottom right that adds to it: its symbol white on its fill,
/// a step larger than the top bar's buttons so it reads as the page's main action.
struct FloatingAddButton: View {
  static let side = 56.0
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
  /// Holds a `FloatingAddButton` at the bottom right, over what scrolls under it.
  func floatingAddButton(
    _ title: String, icon: Icon, fill: Color, isShown: Bool = true,
    action: @escaping () -> Void
  ) -> some View {
    overlay(alignment: .bottomTrailing) {
      if isShown {
        FloatingAddButton(title: title, icon: icon, fill: fill, action: action)
          .padding(.trailing, FloatingAddButton.trailingInset)
          .padding(.bottom, FloatingAddButton.bottomInset)
      }
    }
  }
}

#Preview {
  ScrollView {
    Color.cardFill.frame(height: 1200)
  }
  .floatingAddButton("Log a dive", icon: .divePlus, fill: .brandCoral) {}
}
