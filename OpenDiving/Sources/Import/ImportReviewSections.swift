import OpenDivingKit
import SwiftUI

/// What the import would do, waiting for the diver's *Import*.
struct ImportReviewSections: View {
  let preview: ImportPreview
  let units: UnitSystem
  @Binding var choices: ImportCheckInChoices
  let isImporting: Bool
  let onImport: () -> Void

  var body: some View {
    Section {
      VStack(alignment: .leading, spacing: 2) {
        Text("What the Import Would Do").font(.headline)
        Text("Nothing has been written yet.").font(.subheadline).foregroundStyle(.secondary)
      }
    }
    if !preview.dives.isEmpty {
      Section("Dives (\(preview.dives.count))") {
        ForEach(
          ImportDiveRow.rows(preview.dives, members: preview.members, units: units, written: false)
        ) { row in
          ImportDiveRowView(row: row)
        }
      }
    }
    ImportReportSections(report: preview.report, archive: preview.archive)
    ImportCheckInSection(
      details: preview.checkInDetails, portrait: preview.portrait, choices: $choices)
    Section {
      Button(action: onImport) {
        if isImporting {
          HStack(spacing: 8) {
            ProgressView()
            Text("Importing...")
          }
        } else {
          Text(ImportText.buttonLabel(preview.dives)).fontWeight(.semibold)
        }
      }
      .disabled(isImporting)
    }
  }
}

#Preview {
  @Previewable @State var choices = ImportCheckInChoices()
  NavigationStack {
    List {
      ImportReviewSections(
        preview: ImportPreviewData.preview, units: .metric, choices: $choices, isImporting: false
      ) {}
    }
  }
}
