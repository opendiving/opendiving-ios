import SwiftUI

/// A dive's or a site's tags in the diver's order, each removable, and a box that adds what is
/// typed on Return.
struct TagsField: View {
  let tags: [String]
  var error: String?
  let onAdd: (String) -> Void
  let onRemove: (String) -> Void

  @State private var text = ""

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      FieldLabel("Tags")
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
              .background(Capsule().fill(Color(.secondarySystemFill)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(tag)")
          }
        }
      }
      TextField(tags.isEmpty ? "Add a tag..." : "Add another tag...", text: $text)
        .textInputAutocapitalization(.never)
        .submitLabel(.done)
        .onSubmit {
          onAdd(text)
          text = ""
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
