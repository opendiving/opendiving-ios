import SwiftUI

/// A list row turned into a field for a rename: a tick to save and a cross to stop, the field
/// focused as it opens and *Return* saving.
struct InlineRenameRow: View {
  /// What is being renamed, for the field's and the buttons' spoken labels.
  let original: String
  @Binding var draft: String
  let canSave: Bool
  let isSaving: Bool
  let save: () -> Void
  let stop: () -> Void

  @FocusState private var focused: Bool

  var body: some View {
    HStack(spacing: 12) {
      TextField("Name", text: $draft)
        .focused($focused)
        .submitLabel(.done)
        .onSubmit { if canSave { save() } }
        .disabled(isSaving)
        .accessibilityLabel("New name for \u{201C}\(original)\u{201D}")
      if isSaving {
        BubbleSpinner()
      } else {
        Button(action: save) {
          Image(systemName: "checkmark")
        }
        .accentRow()
        .disabled(!canSave)
        .accessibilityLabel("Save the new name for \u{201C}\(original)\u{201D}")
      }
      Button(action: stop) {
        Image(systemName: "xmark")
      }
      .accentRow()
      .disabled(isSaving)
      .accessibilityLabel("Stop renaming \u{201C}\(original)\u{201D}")
    }
    .buttonStyle(.borderless)
    .onAppear { focused = true }
  }
}

#Preview {
  @Previewable @State var draft = "night"
  List {
    InlineRenameRow(
      original: "night", draft: $draft, canSave: true, isSaving: false, save: {}, stop: {})
  }
}
