import SwiftUI

/// A sheet's confirming action in its top bar: filled, and the weight of the *Cancel* beside it.
struct ToolbarConfirmButton: View {
  let title: String
  var fill = Color.brandTeal
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Text(title)
        .fontWeight(.regular)
        .foregroundStyle(.white)
    }
    .brandProminentButton(fill)
  }
}

#Preview {
  ToolbarConfirmButton(title: "Create") {}
}
