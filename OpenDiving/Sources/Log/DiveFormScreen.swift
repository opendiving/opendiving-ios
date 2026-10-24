import OpenDivingKit
import SwiftUI

/// The form, ready: its sections as the account shows them, a menu that jumps between them, and
/// the actions — *Log dive* or *Save changes*, and *Discard draft* once there is one.
struct DiveFormScreen: View {
  @Bindable var model: DiveFormModel

  @Environment(\.dismiss) private var dismiss
  @State private var confirmsDiscard = false

  var body: some View {
    ScrollViewReader { proxy in
      Form {
        if let sentence = model.serverSentence {
          Section {
            Label(sentence, systemImage: "exclamationmark.triangle")
              .foregroundStyle(.red)
          }
        }
        if model.hasEditDraft {
          Section {
            Text("These are the changes you made earlier and did not save.")
              .foregroundStyle(.secondary)
            Button("Discard changes", role: .destructive) { model.discardEdit() }
          }
        }
        ForEach(model.sections, id: \.self) { group in
          Section(group.title) {
            DiveFormSection(group: group, model: model)
          }
          .id(group)
        }
        Section {
          if let error = model.saveError { FieldMessage(error) }
          Button(model.submitLabel) { submit(proxy) }
            .bold()
          if model.draft != nil {
            Button("Discard draft", role: .destructive) { confirmsDiscard = true }
          }
        } footer: {
          if model.draft != nil {
            Text(
              "Saved as a draft. It reaches your server when the phone can, and opens on the web as you left it."
            )
          }
        }
      }
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Menu("Sections", systemImage: "list.bullet") {
            ForEach(model.sections, id: \.self) { group in
              Button(group.title) {
                withAnimation { proxy.scrollTo(group, anchor: .top) }
              }
            }
          }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button(model.submitLabel) { submit(proxy) }
        }
      }
    }
    .navigationTitle(model.title)
    .navigationBarTitleDisplayMode(.inline)
    .confirmationDialog(
      "Discard draft", isPresented: $confirmsDiscard, titleVisibility: .visible
    ) {
      Button("Discard", role: .destructive) { model.discardDraft() }
    } message: {
      Text("This deletes the draft on every device. It cannot be undone.")
    }
    .onChange(of: model.isDone) { _, done in if done { dismiss() } }
    .onDisappear { model.leave() }
  }

  /// Saves, or scrolls to the first section a sentence landed in.
  private func submit(_ proxy: ScrollViewProxy) {
    guard !model.submit(), let first = model.issues.first else { return }
    let group = DiveFormField(rawValue: first.field)?.group ?? .diveInfo
    withAnimation { proxy.scrollTo(group, anchor: .top) }
  }
}

#Preview {
  NavigationStack {
    DiveFormScreen(model: DiveFormModel(session: DivePreviewData.session, mode: .create))
  }
}
