import OpenDivingKit
import SwiftUI

/// The notes: what they say so far in a row, which opens them full height to write in.
struct NotesField: View {
  let text: String
  var error: String?
  let onChange: (String) -> Void

  @State private var writing = false

  private static let placeholder = "Enter any additional notes about your dive..."

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Button {
        writing = true
      } label: {
        VStack(alignment: .leading, spacing: 6) {
          FieldLabel(DiveFormField.notes.label)
          Text(text.isEmpty ? Self.placeholder : text)
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
      NotesSheet(text: text, onDone: onChange)
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
        .navigationTitle(DiveFormField.notes.label)
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
    NotesField(text: "Drift along the wall, turtle at 18 m.") { _ in }
  }
}
