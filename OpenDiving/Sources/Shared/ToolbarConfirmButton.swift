import SwiftUI

/// A sheet's confirming action in its top bar: filled, and the weight of the *Cancel* beside it.
struct ToolbarConfirmButton: View {
  let title: String
  var fill = Color.brandTeal
  let action: () -> Void

  /// Set by hand both ways: the white replaces the system's dimming, and a disabled button in the
  /// top bar would otherwise keep a full-strength label on its grey.
  @Environment(\.isEnabled) private var isEnabled

  var body: some View {
    Button(action: action) {
      Text(title)
        .fontWeight(.regular)
        .foregroundStyle(isEnabled ? Color.white : Color.secondary)
    }
    .brandProminentButton(fill)
  }
}

#Preview {
  VStack {
    ToolbarConfirmButton(title: "Create") {}
    ToolbarConfirmButton(title: "Create") {}.disabled(true)
  }
}
