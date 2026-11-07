import OpenDivingKit
import SwiftUI

/// Everything an import says besides its dive rows, drawn the same for the review and for the
/// result: the Records table and the Stored files line.
struct ImportReportSections: View {
  let report: LogbookImportRead

  var body: some View {
    let rows = ImportText.recordRows(report)
    if !rows.isEmpty {
      Section("Records") {
        Grid(alignment: .trailing, horizontalSpacing: 12, verticalSpacing: 6) {
          GridRow {
            Text("Type").gridColumnAlignment(.leading)
            Text("New")
            Text("Already here")
            Text("Skipped")
          }
          .font(.caption.weight(.medium))
          ForEach(rows, id: \.collection) { row in
            GridRow {
              Text(ImportText.collectionLabel(row.collection))
              counts(row.created, row.linked, row.skipped)
            }
          }
          Divider()
          GridRow {
            Text("Total").fontWeight(.medium)
            counts(
              rows.reduce(0) { $0 + $1.created }, rows.reduce(0) { $0 + $1.linked },
              rows.reduce(0) { $0 + $1.skipped })
          }
        }
        .font(.footnote)
        .monospacedDigit()
      }
    }
    if let stored = ImportText.storedFiles(report.files) {
      Section("Stored Files") {
        Text(stored).font(.footnote)
        if let hint = ImportText.fileRestoreHint(report) {
          Text(hint).font(.footnote).foregroundStyle(.secondary)
        }
      }
    }
  }

  @ViewBuilder private func counts(_ values: Int...) -> some View {
    ForEach(Array(values.enumerated()), id: \.offset) { _, value in
      Text(String(value))
    }
  }
}

#Preview {
  List {
    ImportReportSections(report: ImportPreviewData.pending)
  }
}
