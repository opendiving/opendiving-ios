import SwiftUI

/// A sheet's confirming action in its top bar: filled, and the weight of the *Cancel* beside it.
struct ToolbarConfirmButton: View {
  let title: String
  var fill = Color.brandTeal
  /// A plain fill with no glass rim, for a bar over a map.
  var isFlat = false
  let action: () -> Void

  @Environment(\.isEnabled) private var isEnabled

  var body: some View {
    if isFlat {
      // Its own capsule: a bar draws a system button style's fill as nothing.
      Button(action: action) {
        label
          .fixedSize()
          .padding(.horizontal, 16)
          .frame(height: 44)
          .background(fill, in: Capsule())
          .opacity(isEnabled ? 1 : 0.5)
      }
      .buttonStyle(.plain)
    } else {
      Button(action: action) { label }
        .brandProminentButton(fill)
    }
  }

  private var label: some View {
    Text(title)
      .fontWeight(.regular)
      .foregroundStyle(.white)
  }
}

#Preview {
  ToolbarConfirmButton(title: "Create") {}
}
