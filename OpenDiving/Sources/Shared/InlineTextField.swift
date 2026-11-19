import SwiftUI

/// A line of text on one row.
struct InlineTextField: View {
  let title: String
  let placeholder: String
  let text: Binding<String>
  var error: String?

  @FocusState private var focused: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      InlineField(title, focus: $focused) {
        TextField(placeholder, text: text)
          .focused($focused)
      }
      if let error { FieldMessage(error) }
    }
  }
}

#Preview {
  @Previewable @State var text = ""
  Form {
    InlineTextField(title: "Instructor number", placeholder: "", text: $text)
  }
}
