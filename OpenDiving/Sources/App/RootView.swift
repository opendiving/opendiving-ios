import OpenDivingKit
import SwiftUI

/// What the window shows — the server and sign-in screens, or the sites map signed in, under the
/// launch splash until the first of them has loaded — and where the one session, the sign-in
/// flow Settings reaches back into, the inbox, the outbox, the dive-computer engine and its
/// screen's model, a tapped download notification and the appearance are injected. The session,
/// the account's load, the inbox and the engine are the app delegate's, made before any view.
struct RootView: View {
  @State private var session: Session
  @State private var signIn: SignInFlow
  @State private var account: AccountLoader
  @State private var inbox: InboxModel
  @State private var outbox: OutboxModel
  @State private var engine: DiveComputerEngine
  @State private var downloads: DiveComputerDownloads
  @State private var notices: NoticeRoute
  @State private var splash = LaunchSplash()
  @State private var appearance = AppearanceModel(defaults: .standard)

  init(
    session: Session, account: AccountLoader, inbox: InboxModel, engine: DiveComputerEngine,
    notices: NoticeRoute = NoticeRoute()
  ) {
    _session = State(initialValue: session)
    _signIn = State(initialValue: SignInFlow(session: session))
    _account = State(initialValue: account)
    _inbox = State(initialValue: inbox)
    _engine = State(initialValue: engine)
    _notices = State(initialValue: notices)
    _downloads = State(initialValue: DiveComputerDownloads { DiveComputerModel(engine: engine) })
    // The quiet load: a reconnect that loads the account raises no alert of its own.
    _outbox = State(
      initialValue: OutboxModel(session: session, loadAccount: { await account.loadQuietly() }))
  }

  var body: some View {
    Group {
      switch session.state {
      // One branch for both, so the sign-in screens keep their place when a server is chosen.
      case .noServer, .signingIn:
        SignInView()
      case .signedIn(let origin):
        // Switching between two signed-in servers starts the app over, rather than
        // showing the last server's lists and screens under the new one.
        SitesView()
          .id(origin)
      }
    }
    .overlay {
      if splash.isShowing {
        LaunchSplashView()
          .transition(.opacity)
      }
    }
    .animation(.easeOut(duration: 0.3), value: splash.isShowing)
    .noticeHost(notices, session: session)
    .environment(session)
    .environment(signIn)
    .environment(downloads)
    .environment(engine)
    .appearanceHost(appearance)
    .inboxHost(inbox, session: session)
    .outboxHost(outbox, session: session)
    .task { await account.launch() }
    .task { await splash.run(session.requests) }
    .onChange(of: session.state) { old, new in
      downloads.sessionChanged()
      engine.sessionChanged()
      Task { await account.sessionChanged(from: old, to: new) }
    }
    .onChange(of: session.accountLoaded) { engine.accountLoaded() }
    .alert(
      "Your account could not be loaded",
      isPresented: Binding(
        get: { account.failure != nil },
        set: { if !$0 { account.dismissFailure() } })
    ) {
      Button("Try again") { Task { await account.retry() } }
      Button("OK", role: .cancel) {}
    } message: {
      Text(account.failure ?? "")
    }
  }
}

extension RootView {
  /// The root over a session alone, with models of its own: a preview's, or a test's.
  init(session: Session) {
    self.init(
      session: session, account: AccountLoader(session: session),
      inbox: InboxModel(session: session),
      engine: DiveComputerEngine(
        session: session, makeLink: { LibDCDiveComputerLink(manager: nil, defaults: .standard) },
        generator: DiveComputerView.generator))
  }
}

#Preview("Signed out") {
  RootView(session: .signedOutStub(origin: nil, transport: StubTransport(routes: [:])))
}

#Preview("Signed in") {
  RootView(session: .stub(transport: StubTransport(routes: [:])))
}
