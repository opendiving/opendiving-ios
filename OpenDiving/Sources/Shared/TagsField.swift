import SwiftUI

/// A dive's or a site's tags in the diver's order, each removable, and a box that adds what is
/// typed on Return and stays open for the next. Return on an empty box closes the keyboard. The
/// box takes several lines only because that keeps its focus: a one-line box gives it up on Return,
/// and taking it back bounces the keyboard and the form with it.
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
      TextField(tags.isEmpty ? "Add a tag..." : "Add another tag...", text: $text, axis: .vertical)
        .textInputAutocapitalization(.never)
        .focused($focused)
        .padding(.top, tags.isEmpty ? 0 : 6)
        .submitLabel(.return)
        .onChange(of: text) { _, typed in
          guard typed.contains(where: \.isNewline) else { return }
          let added = typed.split(whereSeparator: \.isNewline).map(String.init).filter {
            !$0.trimmingCharacters(in: .whitespaces).isEmpty
          }
          text = ""
          if added.isEmpty { focused = false }
          added.forEach(onAdd)
        }
      if let error { FieldMessage(error) }
    }
  }
}

extension View {
  /// Keeps the tag box in view as a new tag pushes it down, since its focus never moves and so
  /// nothing else scrolls the form. `proxy` is the form's, and `id` is what the field carries.
  func followsAddedTags(
    count: Int, id: some Hashable & Sendable, proxy: ScrollViewProxy
  ) -> some View {
    onChange(of: count) { old, new in
      guard new > old else { return }
      withAnimation { proxy.scrollTo(id, anchor: .bottom) }
    }
  }
}

#Preview {
  Form {
    TagsField(tags: ["night", "wreck"], onAdd: { _ in }, onRemove: { _ in })
  }
}
