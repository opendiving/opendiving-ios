import OpenDivingKit
import SwiftUI

/// What a review and a result open on: the files that could not be read, the rows by outcome, and
/// a card for each dive written. Unchanged and skipped dives have no card, so the line counting
/// them leads to the log, which names them.
struct ImportBodySections: View {
  let read: LogbookImportRead
  let units: UnitSystem

  var body: some View {
    let refused = ImportText.refusedFiles(read)
    if !refused.isEmpty {
      Section {
        ForEach(Array(refused.enumerated()), id: \.offset) { _, line in
          Text(line).font(.footnote).foregroundStyle(Color.danger)
        }
      }
    }
    if let summary = ImportText.summary(read.dives) {
      Section {
        if ImportDiveCard.leavesRowsOut(read.dives) {
          ImportLogLink(read: read) { Text(summary).font(.subheadline) }
        } else {
          Text(summary).font(.subheadline)
        }
      }
    }
    ImportDiveCards(read: read, units: units)
  }
}

/// Pushes the import's log.
struct ImportLogLink<Label: View>: View {
  let read: LogbookImportRead
  @ViewBuilder let label: Label

  var body: some View {
    NavigationLink {
      ImportLogView(uuid: read.uuid, written: read.isApplied)
    } label: {
      label
    }
  }
}

#Preview {
  NavigationStack {
    List {
      ImportBodySections(read: ImportPreviewData.pending, units: .metric)
    }
  }
  .environment(DivePreviewData.session)
}
