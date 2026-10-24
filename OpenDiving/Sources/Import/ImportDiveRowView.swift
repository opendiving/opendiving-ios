import OpenDivingKit
import SwiftUI

/// One dive of a review or a result: the start, opening the dive where the row links one,
/// then Dive time, Depth and Recorded by, the files it came from, the outcome and the notes.
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
      ForEach(Array(row.notes.enumerated()), id: \.offset) { _, note in
        ImportNoteLine(badge: note.badge, tone: note.tone, text: note.text)
      }
      if let truncated = row.truncatedNotes {
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
    let data = Data(
      #"""
      {"uuid":null,"outcome":"created","files_added":0,"recordings_added":0,"reason":null,
       "start_time":"2026-09-14T09:12:00+03:00","submerged_time":2940,"max_depth":24.6,
       "device":null,"members":[],"notes":[],"notes_truncated":0}
      """#.utf8)
    let dive = try! APICoding.decoder().decode(ImportDiveReport.self, from: data)
    return ImportDiveRow.rows([dive], members: [], units: .metric, written: false)[0]
  }
}
