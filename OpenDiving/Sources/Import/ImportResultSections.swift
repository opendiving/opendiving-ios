import OpenDivingKit
import SwiftUI

/// What the import wrote: each dive it reached, opening the dive, then the rest of the report.
struct ImportResultSections: View {
  let result: ImportResult
  let numbering: String?
  let units: UnitSystem
  let onDone: () -> Void

  var body: some View {
    Section {
      VStack(alignment: .leading, spacing: 2) {
        Text("Imported").font(.headline)
        Text("The import is written. Each dive below says what happened to it.")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }
    }
    if !result.dives.isEmpty {
      Section {
        ForEach(
          ImportDiveRow.rows(result.dives, members: result.members, units: units, written: true)
        ) { row in
          ImportDiveRowView(row: row)
        }
      }
    }
    if let numbering {
      Section {
        Text(numbering).font(.footnote).foregroundStyle(.secondary)
      }
    }
    ImportReportSections(report: result, archive: true)
    Section {
      Button("Done", action: onDone)
    }
  }
}

#Preview {
  NavigationStack {
    List {
      ImportResultSections(
        result: ImportPreviewData.preview.report,
        numbering: "Numbered #1–#3 — 2 dives share a number.", units: .metric
      ) {}
    }
  }
}
