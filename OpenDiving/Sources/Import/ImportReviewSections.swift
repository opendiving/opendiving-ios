import OpenDivingKit
import SwiftUI

/// The import waiting for the diver's *Import* or *Discard*, from whichever device uploaded it.
struct ImportReviewSections: View {
  let pending: LogbookImportRead
  let units: UnitSystem
  @Binding var choices: ImportCheckInChoices
  let phase: InboxModel.Phase
  let onImport: () -> Void
  let onDiscard: () -> Void

  var body: some View {
    Section {
      VStack(alignment: .leading, spacing: 2) {
        Text("Review This Import").font(.headline)
        Text(ImportText.reviewLine(expiresAt: pending.expiresAt))
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }
    }
    ImportBodySections(read: pending, units: units)
    ImportReportSections(report: pending)
    ImportCheckInSection(
      details: pending.checkInDetails, portrait: pending.portrait, choices: $choices)
    Section {
      ImportLogLink(read: pending) { Text("Import log") }
    }
    Section {
      Button(action: onImport) {
        if phase == .importing {
          HStack(spacing: 8) {
            BubbleSpinner()
            Text("Importing...")
          }
        } else {
          Text(ImportText.buttonLabel(pending.dives)).fontWeight(.semibold)
        }
      }
      .accentRow()
      .disabled(phase != .idle)
      Button("Discard", role: .destructive, action: onDiscard)
        .dangerRow()
        .disabled(phase != .idle)
    }
  }
}

#Preview {
  @Previewable @State var choices = ImportCheckInChoices()
  NavigationStack {
    List {
      ImportReviewSections(
        pending: ImportPreviewData.pending, units: .metric, choices: $choices, phase: .idle,
        onImport: {}, onDiscard: {})
    }
  }
  .environment(DivePreviewData.session)
}
