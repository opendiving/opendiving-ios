import OpenDivingKit
import SwiftUI

/// One applied import, pushed from the history: the result as it stood, and its *Delete*.
struct ImportDetailView: View {
  let uuid: UUID

  @Environment(Session.self) private var session
  @State private var model: ImportDetailModel?

  var body: some View {
    Group {
      if let model {
        ImportDetailScreen(model: model, units: session.units)
      } else {
        EmptyOrErrorView(status: .loading)
      }
    }
    .navigationTitle("Import")
    .navigationBarTitleDisplayMode(.inline)
    .task {
      guard model == nil else { return }
      let model = ImportDetailModel(session: session, uuid: uuid)
      self.model = model
      await model.load()
    }
  }
}

private struct ImportDetailScreen: View {
  let model: ImportDetailModel
  let units: UnitSystem

  @Environment(\.dismiss) private var dismiss

  var body: some View {
    switch model.phase {
    case .loading:
      EmptyOrErrorView(status: .loading)
    case .failed(.http(404, _)):
      EmptyOrErrorView(status: .notFound(message: "This import could not be found."))
    case .failed(let error):
      EmptyOrErrorView(status: .failed(message: error.message)) {
        Task { await model.load() }
      }
    case .loaded(let read):
      List {
        ImportResultSections(result: read, numbering: model.numbering, units: units)
        if let error = model.deleteError {
          Section {
            Text(error).foregroundStyle(Color.danger)
          }
        }
        DeleteRecordSection(
          title: "Delete import",
          message: "Its review and log leave your history. The dives it wrote stay in your "
            + "logbook."
        ) {
          Task {
            if await model.delete() { dismiss() }
          }
        }
        .disabled(model.isDeleting)
      }
    }
  }
}

#Preview {
  NavigationStack {
    ImportDetailView(uuid: ImportPreviewData.applied.uuid)
  }
  .environment(ImportPreviewData.session)
}
