import OpenDivingKit
import SwiftUI

/// The form, ready: its sections as the account shows them, a menu that jumps between them,
/// *Discard draft* once there is one, *Delete dive* at the end of an edit, and *Log dive* or *Save
/// changes* fixed under it all.
struct DiveFormScreen: View {
  @Bindable var model: DiveFormModel
  var onDeleted: () -> Void = {}
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
              .foregroundStyle(Color.danger)
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
              .dangerRow()
          }
        }
        ForEach(model.sections, id: \.self) { group in
          if group == .tanks {
            TanksSection(model: model)
          } else {
            Section {
              DiveFormSection(group: group, model: model)
            } header: {
              FormSectionHeader(group: group)
            }
            .id(group)
            // Named, or the section takes the spacing of the tank card after it.
            .listSectionSpacing(.default)
          }
        }
        if model.draft != nil {
          Section {
            Button("Discard draft", role: .destructive) { confirmsDiscard = true }
              .dangerRow()
          } footer: {
            Text(
              "Saved as a draft. It reaches your server when the phone can, and opens on the web as you left it."
            )
          }
        }
        if model.canDelete {
          DeleteRecordSection(
            title: "Delete dive", message: RecordDeletionText.dive, action: model.deleteDive)
        }
      }
      // A list scrolls to a section's first row, takes no anchor but top, centre and bottom, and
      // aligns to the safe area, so only this keeps a jumped-to section's title in view.
      .safeAreaInset(edge: .top, spacing: 0) {
        Color.clear.frame(height: 30).allowsHitTesting(false)
      }
      .environment(\.defaultMinListRowHeight, 1)
      .background(TapEndsTyping())
      .followsAddedTags(count: model.values.tags.count, id: DiveFormField.tags, proxy: proxy)
      .pinnedToBottom { saveBar(proxy) }
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Menu("Sections", systemImage: "list.bullet") {
            ForEach(model.sections, id: \.self) { group in
              Button {
                withAnimation { proxy.scrollTo(group, anchor: .top) }
              } label: {
                Label(menuItem: group.title, icon: group.icon)
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
    // Here and not on a gear row: a row scrolled out of the form takes its sheets with it.
    .sheet(isPresented: $model.isChecklistOpen) {
      GearChecklistSheet(model: model)
    }
    .onChange(of: model.isDone) { _, done in
      guard done else { return }
      dismiss()
      if model.isDeleted { onDeleted() }
    }
    .onDisappear { model.leave() }
  }

  /// The save button, the screen's width inside its margins, and what stopped the last save above
  /// it, since the end of the form may be far from view.
  private func saveBar(_ proxy: ScrollViewProxy) -> some View {
    FormSaveBar(label: model.submitLabel, error: model.saveError) { submit(proxy) }
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
