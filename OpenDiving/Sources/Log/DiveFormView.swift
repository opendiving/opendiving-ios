import OpenDivingKit
import SwiftUI

/// The dive form: a new dive, a draft, an edit of a dive the account has, or a queued dive the
/// server refused. A new form offers the drafts that exist until it is touched. It is pushed
/// onto a navigation stack and pops itself once its work is queued.
struct DiveFormView: View {
  let mode: DiveFormMode

  @Environment(Session.self) private var session
  @State private var model: DiveFormModel?

  init(mode: DiveFormMode) {
    self.mode = mode
  }

  var body: some View {
    Group {
      if let model {
        content(model)
      } else {
        EmptyOrErrorView(status: .loading)
      }
    }
    .task {
      guard model == nil else { return }
      await open(mode.form)
    }
  }

  @ViewBuilder private func content(_ model: DiveFormModel) -> some View {
    switch model.phase {
    case .loading:
      EmptyOrErrorView(status: .loading)
        .navigationTitle(model.title)
        .navigationBarTitleDisplayMode(.inline)
    case .unavailable(let sentence):
      EmptyOrErrorView(status: .notFound(message: sentence))
        .navigationTitle(model.title)
        .navigationBarTitleDisplayMode(.inline)
    case .ready:
      // The drafts sit above a new form rather than in place of it, so a drafts list that
      // arrives while the form is open adds a section instead of tearing the form down.
      DiveFormScreen(model: model) { ref in
        Task { await open(.draft(ref)) }
      }
      .id(ObjectIdentifier(model))
    }
  }

  private func open(_ mode: DiveFormModel.Mode) async {
    let model = DiveFormModel(session: session, mode: mode)
    self.model = model
    await model.start()
  }
}

extension DiveFormMode {
  /// The mode as the Kit's form model takes it.
  var form: DiveFormModel.Mode {
    switch self {
    case .create: .create
    case .draft(let ref): .draft(ref)
    case .edit(let uuid): .edit(uuid)
    case .failed(let id): .failed(id)
    }
  }
}

#Preview("Log") {
  NavigationStack { DiveFormView(mode: .create) }
    .environment(DivePreviewData.session)
}

#Preview("Edit") {
  NavigationStack { DiveFormView(mode: .edit(DivePreviewData.diveUUID)) }
    .environment(DivePreviewData.session)
}
