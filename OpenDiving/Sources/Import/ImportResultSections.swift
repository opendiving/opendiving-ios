import OpenDivingKit
import SwiftUI

/// What an import wrote, straight after the apply and from the history alike. `onDone` is the
/// way back where the screen has no back button of its own to offer.
struct ImportResultSections: View {
  let result: LogbookImportRead
  let numbering: String?
  let units: UnitSystem
  var onDone: (() -> Void)?

  var body: some View {
    Section {
      VStack(alignment: .leading, spacing: 2) {
        Text("Imported").font(.headline)
        if let line = ImportText.appliedLine(result.appliedAt) {
          Text(line).font(.subheadline).foregroundStyle(.secondary)
        }
      }
    }
    ImportBodySections(read: result, units: units)
    if let numbering {
      Section {
        Text(numbering).font(.footnote).foregroundStyle(.secondary)
      }
    }
    ImportReportSections(report: result)
    Section {
      ImportLogLink(read: result) { Text("Import log") }
    }
    if let onDone {
      Section {
        Button("Done", action: onDone)
          .accentRow()
      }
    }
  }
}

#Preview {
  NavigationStack {
    List {
      ImportResultSections(
        result: ImportPreviewData.applied,
        numbering: "Numbered #1–#3 — 2 dives share a number.", units: .metric
      ) {}
    }
  }
  .environment(DivePreviewData.session)
}
