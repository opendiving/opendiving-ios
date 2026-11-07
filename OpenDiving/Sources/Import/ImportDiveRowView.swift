import OpenDivingKit
import SwiftUI

/// One dive of a review or a result: the start, opening the dive where the row links one,
/// then Dive time, Depth and Recorded by, the files it came from, the outcome, and why a skipped
/// dive was skipped.
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
    }
  }

  private var content: some View {
    VStack(alignment: .leading, spacing: 2) {
      HStack(alignment: .firstTextBaseline) {
        Text(row.start).font(.subheadline.weight(.medium))
        Spacer()
        Text(row.outcome).font(.subheadline)
      }
      Text("Dive time \(row.diveTime) · Depth \(row.depth) · Recorded by \(row.recordedBy)")
        .font(.caption)
        .foregroundStyle(.secondary)
      if !row.files.isEmpty {
        Text("Files: " + row.files.joined(separator: ", "))
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
  }
}

#Preview {
  List {
    ImportDiveRowView(row: .preview)
  }
}

extension ImportDiveRow {
  /// A row for previews.
  fileprivate static var preview: ImportDiveRow {
    ImportDiveRow.rows(
      ImportPreviewData.pending.dives, members: ImportPreviewData.pending.members, units: .metric,
      written: false)[0]
  }
}
