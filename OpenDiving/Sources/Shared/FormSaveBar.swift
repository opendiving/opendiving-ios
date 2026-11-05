import SwiftUI

/// A pushed form's save button, the screen's width inside its margins, and what stopped the last
/// save above it, since the end of the form may be far from view.
struct FormSaveBar: View {
  let label: String
  let error: String?
  let action: () -> Void

  var body: some View {
    VStack(spacing: 8) {
      if let error {
        FieldMessage(error)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(8)
          .background(.bar, in: RoundedRectangle(cornerRadius: 8))
      }
      Button(action: action) {
        Text(label)
          .bold()
          .frame(maxWidth: .infinity)
      }
      .brandProminentButton()
      .controlSize(.large)
    }
    .padding(.horizontal)
    .padding(.vertical, 8)
  }
}

#Preview {
  FormSaveBar(label: "Save changes", error: "Name is required.") {}
}
