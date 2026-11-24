import OpenDivingKit
import SwiftUI

extension View {
  /// Where files shared to the app arrive, for the window's whole life: the inbox model in the
  /// environment, told when the session changes and when a route appears, so what arrived goes
  /// up, and the import screen shown when a file arrives signed in, its review opening there.
  /// Every other address iOS opens in the app goes to `link`.
  func inboxHost(
    _ inbox: InboxModel, session: Session, link: @escaping (URL) -> Void
  ) -> some View {
    modifier(InboxHost(inbox: inbox, session: session, link: link))
  }
}

private struct InboxHost: ViewModifier {
  let inbox: InboxModel
  let session: Session
  let link: (URL) -> Void

  @State private var showingImport = false
  @State private var notice: Notice?

  private struct Notice {
    let title: String
    let message: String
  }

  func body(content: Content) -> some View {
    content
      .environment(inbox)
      // SwiftUI hands a document iOS opens in the app to `onOpenURL`, as it does a link; see
      // DECISIONS.md, "Shared files are imported types, copied in".
      .onOpenURL { receive($0) }
      .onChange(of: session.state) { inbox.sessionChanged() }
      .onChange(of: session.accountLoaded) { inbox.sessionChanged() }
      .task {
        for await _ in session.connectivity.moments() { inbox.uploadArrivals() }
      }
      .sheet(isPresented: $showingImport) {
        NavigationStack {
          ImportView(shared: true)
            .toolbar {
              ToolbarItem(placement: .confirmationAction) {
                Button("Done") { showingImport = false }
              }
            }
        }
        .environment(session)
        .environment(inbox)
      }
      .alert(
        notice?.title ?? "",
        isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } }),
        presenting: notice
      ) { _ in
        Button("OK", role: .cancel) {}
      } message: { notice in
        Text(notice.message)
      }
  }

  private func receive(_ url: URL) {
    guard url.isFileURL else {
      link(url)
      return
    }
    guard let staged = SharedFileStaging.stage(url) else {
      notice = Notice(title: "The file was not kept", message: "It could not be read.")
      return
    }
    switch inbox.receive([staged], moving: true) {
    case .kept(_, signedIn: true):
      showingImport = true
    case .kept(_, signedIn: false):
      notice = Notice(
        title: "The file is waiting", message: "It is uploaded once you sign in.")
    case .notKept(let reason):
      try? FileManager.default.removeItem(at: staged)
      notice = Notice(title: "The file was not kept", message: reason)
    }
  }
}
