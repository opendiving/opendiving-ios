import OpenDivingKit
import SwiftUI

/// Everything a report says besides its dive rows, drawn the same for the review and for the
/// result: the Records table, the Stored files line and the Notes list.
struct ImportReportSections: View {
  let report: ImportReport
  /// Whether the files carried a full-export archive; a result passes true, since its
  /// advice to import the archive would be about a decision already taken.
  let archive: Bool

  var body: some View {
    let rows = ImportText.recordRows(report)
    if !rows.isEmpty {
      Section("Records") {
        Grid(alignment: .trailing, horizontalSpacing: 12, verticalSpacing: 6) {
          GridRow {
            Text("Type").gridColumnAlignment(.leading)
            Text("New")
            Text("Already here")
            Text("Restored")
            Text("Skipped")
          }
          .font(.caption.weight(.medium))
          ForEach(rows, id: \.collection) { row in
            GridRow {
              Text(ImportText.collectionLabel(row.collection))
              counts(row.created, row.linked, row.restored, row.skipped)
            }
          }
          Divider()
          GridRow {
            Text("Total").fontWeight(.medium)
            counts(
              rows.reduce(0) { $0 + $1.created }, rows.reduce(0) { $0 + $1.linked },
              rows.reduce(0) { $0 + $1.restored }, rows.reduce(0) { $0 + $1.skipped })
          }
        }
        .font(.footnote)
        .monospacedDigit()
      }
    }
    if let stored = ImportText.storedFiles(report.files) {
      Section("Stored Files") {
        Text(stored).font(.footnote)
        if let hint = ImportText.fileRestoreHint(report, archive: archive) {
          Text(hint).font(.footnote).foregroundStyle(.secondary)
        }
      }
    }
    let truncated = ImportText.truncatedNotes(report.notesTruncated)
    if !report.notes.isEmpty || truncated != nil {
      Section(report.notes.isEmpty ? "Notes" : "Notes (\(report.notes.count))") {
        ForEach(Array(report.notes.enumerated()), id: \.offset) { _, group in
          ImportNoteLine(
            badge: ImportText.noteKind(group.kind), tone: ImportText.noteTone(group.kind),
            text: ImportText.noteText(collection: group.collection, message: group.message),
            places: ImportText.notePlaces(group))
        }
        if let truncated {
          Text(truncated).font(.footnote).italic().foregroundStyle(.secondary)
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
    ImportReportSections(report: ImportPreviewData.preview.report, archive: false)
  }
}
