import SwiftUI

/// A dive's or a site's tags in the diver's order, each removable, and a box that adds what is
/// typed on Return and stays open for the next. Return on an empty box closes the keyboard.
struct TagsField: View {
  let tags: [String]
  var error: String?
  let onAdd: (String) -> Void
  let onRemove: (String) -> Void

  @State private var text = ""
  @FocusState private var focused: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      FieldLabel("Tags")
        .contentShape(Rectangle())
        .onTapGesture { focused = true }
      if !tags.isEmpty {
        FlowLayout(spacing: 6) {
          ForEach(tags, id: \.self) { tag in
            Button {
              onRemove(tag)
            } label: {
              HStack(spacing: 4) {
                Text(tag)
                Image(systemName: "xmark").font(.caption2)
              }
              .font(.subheadline)
              .padding(.horizontal, 10)
              .padding(.vertical, 4)
              .foregroundStyle(Color.white)
              .background(RoundedRectangle(cornerRadius: 6).fill(Color.brandTeal))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(tag)")
          }
        }
      }
      TextField(tags.isEmpty ? "Add a tag..." : "Add another tag...", text: $text)
        .textInputAutocapitalization(.never)
        .focused($focused)
        .padding(.top, tags.isEmpty ? 0 : 6)
        .submitLabel(.return)
        .onSubmit {
          guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
          onAdd(text)
          text = ""
          focused = true
        }
      if let error { FieldMessage(error) }
    }
  }
}

#Preview {
  Form {
    TagsField(tags: ["night", "wreck"], onAdd: { _ in }, onRemove: { _ in })
  }
}
