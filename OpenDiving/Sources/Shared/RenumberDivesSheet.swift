import OpenDivingKit
import SwiftUI

/// The web's *Renumber Dives* dialog: the number to start at and the first day, every dive the
/// renumber moves, and *Renumber*, which writes only the renumber listed. The one thing in the app
/// that rewrites numbers a diver typed, so nothing opens it but the diver. `onRenumbered` hears once
/// the numbers are written, as the sheet closes.
struct RenumberDivesSheet: View {
  var defaults = RenumberDefaults.wholeLog
  var onRenumbered: () -> Void = {}

  @Environment(Session.self) private var session

  var body: some View {
    RenumberDivesForm(
      model: RenumberModel(session: session, defaults: defaults), onRenumbered: onRenumbered)
  }
}

private struct RenumberDivesForm: View {
  @State var model: RenumberModel
  let onRenumbered: () -> Void

  @Environment(\.dismiss) private var dismiss
  @FocusState private var startFocused: Bool

  var body: some View {
    NavigationStack {
      Form {
        Section {
          Text(DiveNumberingText.intro)
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        Section {
          InlineField("Start at", focus: $startFocused) {
            TextField("", text: $model.startAtText)
              .keyboardType(.numberPad)
              .focused($startFocused)
          }
          CalendarDateField(label: "Only dives from", date: $model.fromDate)
        } footer: {
          Text(DiveNumberingText.startAtNote + " " + DiveNumberingText.fromDateNote)
        }
        .disabled(model.isApplying)
        Section {
          HStack(spacing: 8) {
            if model.isWorking {
              BubbleSpinner()
                .controlSize(.small)
            }
            Text(model.statusLine)
              .foregroundStyle(model.changes.isEmpty ? .secondary : .primary)
          }
          ForEach(model.changes) { change in
            LabeledContent {
              Text(DateText.diveDateTime(change.startTime))
            } label: {
              Text(DiveNumberingText.move(change))
                .monospacedDigit()
            }
          }
        }
        if let error = model.applyError {
          Section {
            Text(error).foregroundStyle(Color.danger)
          }
        }
      }
      .background(TapEndsTyping())
      .navigationTitle("Renumber Dives")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
            .disabled(model.isApplying)
        }
        ToolbarItem(placement: .confirmationAction) {
          ToolbarConfirmButton(title: "Renumber") {
            Task {
              guard await model.apply() != nil else { return }
              onRenumbered()
              dismiss()
            }
          }
          .disabled(!model.canApply)
        }
      }
      // Keyed by the fields, so a change cancels the preview on its way and asks again.
      .task(id: model.inputs) { await model.preview() }
      .interactiveDismissDisabled(model.isApplying)
    }
  }
}

#Preview {
  Text("Dives")
    .sheet(isPresented: .constant(true)) {
      RenumberDivesSheet()
    }
    .environment(DivePreviewData.session)
}
