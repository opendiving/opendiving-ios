import OpenDivingKit
import SwiftUI

/// What the import would do, waiting for the diver's *Import* or *Discard*.
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
        Text("What the Import Would Do").font(.headline)
        Text("Nothing has been written yet.").font(.subheadline).foregroundStyle(.secondary)
      }
    }
    if !pending.dives.isEmpty {
      Section("Dives (\(pending.dives.count))") {
        ForEach(
          ImportDiveRow.rows(pending.dives, members: pending.members, units: units, written: false)
        ) { row in
          ImportDiveRowView(row: row)
        }
      }
    }
    ImportReportSections(report: pending)
    ImportCheckInSection(
      details: pending.checkInDetails, portrait: pending.portrait, choices: $choices)
    Section {
      Button(action: onImport) {
        if phase == .importing {
          HStack(spacing: 8) {
            ProgressView()
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
}
