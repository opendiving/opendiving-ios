import OpenDivingKit
import SwiftUI

/// One dive of an import's log: the start, opening the dive where the row links one, what recorded
/// it, the outcome, why a skipped dive was skipped, and what the import has to say about it.
struct ImportDiveRowView: View {
  let row: ImportDiveRow

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      if let uuid = row.opens {
        NavigationLink {
          DiveDetailView(diveUUID: uuid)
        } label: {
          content
        }
      } else {
        content
      }
      if let reason = row.reason {
        ImportNoteLine(badge: nil, tone: .warning, text: reason)
      }
      ForEach(Array(row.notes.enumerated()), id: \.offset) { _, note in
        ImportNoteLine(badge: note.badge, tone: note.tone, text: note.text)
      }
      if let truncated = row.notesTruncated {
        Text(truncated).font(.caption).italic().foregroundStyle(.secondary)
      }
    }
  }

  private var content: some View {
    VStack(alignment: .leading, spacing: 2) {
      HStack(alignment: .firstTextBaseline) {
        Text(row.start).font(.subheadline.weight(.medium))
        Spacer()
        Text(row.outcome).font(.subheadline)
      }
      if let recordedBy = row.recordedBy {
        Text("Recorded by \(recordedBy)")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
  }
}

#Preview {
  NavigationStack {
    List {
      ForEach(ImportLogContent(ImportPreviewData.notes, written: true).dives) { row in
        ImportDiveRowView(row: row)
      }
    }
  }
}
