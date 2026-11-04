import OpenDivingKit
import SwiftUI

/// The form, ready: its sections as the account shows them, a menu that jumps between them,
/// *Discard draft* once there is one, and *Log dive* or *Save changes* fixed under it all, where
/// the tab bar was.
struct DiveFormScreen: View {
  @Bindable var model: DiveFormModel
  /// Opens a draft in place of a new form that has not been touched.
  var onContinueDraft: ((RecordRef) -> Void)?

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
        if let onContinueDraft, model.mode == .create, !model.isTouched,
          !model.draftRows.isEmpty
        {
          DiveDraftChooser(rows: model.draftRows, onPick: onContinueDraft)
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
        if model.draft != nil {
          Section {
            Button("Discard draft", role: .destructive) { confirmsDiscard = true }
          } footer: {
            Text(
              "Saved as a draft. It reaches your server when the phone can, and opens on the web as you left it."
            )
          }
        }
      }
      .safeAreaInset(edge: .bottom, spacing: 0) { saveBar(proxy) }
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

  /// The save button, the bar's full width and down through the home indicator, and what stopped
  /// the last save above it, since the end of the form may be far from view.
  private func saveBar(_ proxy: ScrollViewProxy) -> some View {
    VStack(spacing: 0) {
      if let error = model.saveError {
        FieldMessage(error)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal)
          .padding(.vertical, 8)
          .background(.bar)
      }
      Button {
        submit(proxy)
      } label: {
        Text(model.submitLabel)
          .bold()
          .foregroundStyle(.white)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 16)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .background(Color.teal, ignoresSafeAreaEdges: .bottom)
    }
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
