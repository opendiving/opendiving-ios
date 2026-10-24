import SwiftUI

/// The sentence under a field, in the form's error colour; nothing without one.
struct FieldMessage: View {
  let text: String?

  var body: some View {
    if let text {
      Text(text)
        .font(.footnote)
        .foregroundStyle(.red)
    }
  }
}

#Preview {
  FieldMessage(text: "Name is required")
}
