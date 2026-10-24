import SwiftUI

/// A sentence under a field: what the form refuses, in red, or a note, in grey.
struct FieldMessage: View {
  let text: String
  var isNote = false

  init(_ text: String, isNote: Bool = false) {
    self.text = text
    self.isNote = isNote
  }

  var body: some View {
    Text(text)
      .font(.footnote)
      .foregroundStyle(isNote ? Color.secondary : Color.red)
      .fixedSize(horizontal: false, vertical: true)
  }
}

#Preview {
  VStack(alignment: .leading) {
    FieldMessage("Dive time is required")
    FieldMessage("Another dive is already numbered #12.", isNote: true)
  }
}
