import SwiftUI

/// A record's notes: what they say so far in a row, which opens them full height to write in.
struct NotesField: View {
  let placeholder: String
  @Binding var text: String
  var error: String?

  @State private var writing = false

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Button {
        writing = true
      } label: {
        VStack(alignment: .leading, spacing: 6) {
          FieldLabel("Notes")
          Text(text.isEmpty ? placeholder : text)
            .foregroundStyle(text.isEmpty ? Color(.placeholderText) : Color.primary)
            .lineLimit(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      if let error { FieldMessage(error) }
    }
    .sheet(isPresented: $writing) {
      NotesSheet(text: text) { text = $0 }
    }
  }
}

/// The notes at full height. *Done* keeps them and *Cancel* does not; a swipe down is refused once
/// they have changed, since it would throw away what was written.
private struct NotesSheet: View {
  let text: String
  let onDone: (String) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var draft: String
  @FocusState private var focused: Bool

  init(text: String, onDone: @escaping (String) -> Void) {
    self.text = text
    self.onDone = onDone
    _draft = State(initialValue: text)
  }

  var body: some View {
    NavigationStack {
      TextEditor(text: $draft)
        .focused($focused)
        .padding(.horizontal)
        .navigationTitle("Notes")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }
          }
          ToolbarItem(placement: .confirmationAction) {
            Button {
              onDone(draft)
              dismiss()
            } label: {
              Text("Done").fontWeight(.regular).foregroundStyle(.white)
            }
            .buttonStyle(.borderedProminent)
            .tint(.brandTeal)
          }
        }
    }
    .interactiveDismissDisabled(draft != text)
    .onAppear { focused = true }
  }
}

#Preview {
  Form {
    NotesField(placeholder: "Any notes...", text: .constant("Turtle at 18 m."))
  }
}
