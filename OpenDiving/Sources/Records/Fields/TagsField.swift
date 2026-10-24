import SwiftUI

/// A site's tags: each one a row to remove, a box to add the next — the same tag twice, in any
/// case, is one tag.
struct TagsField: View {
  @Binding var tags: [String]
  var message: String?

  @State private var next = ""

  var body: some View {
    Section("Tags") {
      ForEach(tags, id: \.self) { tag in Text(tag) }
        .onDelete { tags.remove(atOffsets: $0) }
      TextField("Tag", text: $next, prompt: Text("Add a tag"))
        .submitLabel(.done)
        .onSubmit(add)
      FieldMessage(text: message)
    }
  }

  private func add() {
    let tag = next.trimmingCharacters(in: .whitespacesAndNewlines)
    next = ""
    guard !tag.isEmpty, !tags.contains(where: { $0.caseInsensitiveCompare(tag) == .orderedSame })
    else { return }
    tags.append(tag)
  }
}

#Preview {
  @Previewable @State var tags = ["wreck"]
  Form { TagsField(tags: $tags) }
}
