import OpenDivingKit
import SwiftUI

/// The round button held at a list's bottom right that adds to it: the dive-plus symbol white on
/// its fill, a step larger than the top bar's buttons so it reads as the page's main action.
struct FloatingAddButton: View {
  static let side = 56.0
  /// From the screen's trailing and bottom edges, as far as a top bar's buttons sit from its sides.
  static let inset = 16.0

  let title: String
  let fill: Color
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Image(Icon.divePlus)
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
    _ title: String, fill: Color, isShown: Bool = true, action: @escaping () -> Void
  ) -> some View {
    overlay(alignment: .bottomTrailing) {
      if isShown {
        FloatingAddButton(title: title, fill: fill, action: action)
          .padding([.trailing, .bottom], FloatingAddButton.inset)
      }
    }
  }
}

#Preview {
  ScrollView {
    Color.cardFill.frame(height: 1200)
  }
  .floatingAddButton("Log a dive", fill: .brandCoral) {}
}
