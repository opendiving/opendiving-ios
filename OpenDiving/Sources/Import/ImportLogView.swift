import OpenDivingKit
import SwiftUI

/// *Import log*: every dive of an import, the ones without a card among them, and everything the
/// import has to say. Kept off the review, not being needed most of the time.
struct ImportLogView: View {
  let uuid: UUID
  /// Whether the import has been applied.
  let written: Bool

  @Environment(Session.self) private var session
  @State private var model: ImportLogModel?

  var body: some View {
    Group {
      switch model?.phase {
      case nil, .loading:
        EmptyOrErrorView(status: .loading)
      case .failed(.http(404, _)):
        EmptyOrErrorView(status: .notFound(message: "This import's log could not be found."))
      case .failed(let error):
        EmptyOrErrorView(status: .failed(message: error.message)) {
          Task { await model?.load() }
        }
      case .loaded(let content):
        ImportLogList(content: content)
      }
    }
    .navigationTitle("Import log")
    .navigationBarTitleDisplayMode(.inline)
    .task {
      guard model == nil else { return }
      let model = ImportLogModel(session: session, uuid: uuid, written: written)
      self.model = model
      await model.load()
    }
  }
}

private struct ImportLogList: View {
  let content: ImportLogContent

  var body: some View {
    List {
      if !content.dives.isEmpty {
        Section("Dives (\(content.dives.count))") {
          ForEach(content.dives) { row in
            ImportDiveRowView(row: row)
          }
        }
      }
      if !content.notes.isEmpty || content.notesTruncated != nil {
        Section(content.notes.isEmpty ? "Notes" : "Notes (\(content.notes.count))") {
          ForEach(Array(content.notes.enumerated()), id: \.offset) { _, note in
            ImportNoteLine(
              badge: note.badge, tone: note.tone, text: note.text, places: note.places)
          }
          if let truncated = content.notesTruncated {
            Text(truncated).font(.footnote).italic().foregroundStyle(.secondary)
          }
        }
      }
    }
  }
}

#Preview {
  NavigationStack {
    ImportLogView(uuid: ImportPreviewData.applied.uuid, written: true)
  }
  .environment(ImportPreviewData.session)
}
