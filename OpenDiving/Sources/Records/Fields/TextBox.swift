import SwiftUI

/// A labelled box as the web's dialogs draw one: the label above, the placeholder inside, the
/// sentence below.
struct TextBox: View {
  let label: String
  var placeholder: String?
  @Binding var text: String
  var message: String?
  var keyboard: UIKeyboardType = .default
  var contentType: UITextContentType?
  /// Usernames, emails and web addresses are typed as they are.
  var verbatim = false
  /// Notes grow with what is typed.
  var multiline = false

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(label).font(.subheadline.weight(.medium))
      Group {
        if multiline {
          TextField(label, text: $text, prompt: placeholder.map(Text.init), axis: .vertical)
            .lineLimit(3...8)
        } else {
          TextField(label, text: $text, prompt: placeholder.map(Text.init))
        }
      }
      .keyboardType(keyboard)
      .textContentType(contentType)
      .textInputAutocapitalization(verbatim ? .never : nil)
      .autocorrectionDisabled(verbatim)
      .labelsHidden()
      FieldMessage(text: message)
    }
  }
}

#Preview {
  @Previewable @State var name = ""
  Form {
    TextBox(label: "Name *", placeholder: "e.g. Alex M.", text: $name, message: "Name is required")
  }
}
