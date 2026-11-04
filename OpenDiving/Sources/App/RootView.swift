import OpenDivingKit
import SwiftUI

/// What the window shows — the server and sign-in screens, or the signed-in shell, under the
/// launch splash until the first of them has loaded — and where the one session, the sign-in
/// flow Settings reaches back into, the inbox, the outbox and the dive-computer download are
/// injected.
struct RootView: View {
  @State private var session: Session
  @State private var signIn: SignInFlow
  @State private var account: AccountLoader
  @State private var inbox: InboxModel
  @State private var outbox: OutboxModel
  @State private var downloads: DiveComputerDownloads
  @State private var splash = LaunchSplash()

  init(session: Session = .device()) {
    let account = AccountLoader(session: session)
    _session = State(initialValue: session)
    _signIn = State(initialValue: SignInFlow(session: session))
    _account = State(initialValue: account)
    let inbox = InboxModel(session: session)
    _inbox = State(initialValue: inbox)
    _downloads = State(
      initialValue: DiveComputerDownloads {
        DiveComputerModel(
          session: session, inbox: inbox, link: LibDCDiveComputerLink(),
          generator: DiveComputerView.generator)
      })
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
        // Switching between two signed-in servers starts the shell over, rather than
        // showing the last server's lists and screens under the new one.
        MainTabView()
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
    .environment(session)
    .environment(signIn)
    .environment(downloads)
    .inboxHost(inbox, session: session)
    .outboxHost(outbox, session: session)
    .task { await account.launch() }
    .task { await splash.run(session.requests) }
    .onChange(of: session.state) { old, new in
      downloads.sessionChanged()
      Task { await account.sessionChanged(from: old, to: new) }
    }
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

#Preview("Signed out") {
  RootView(session: .signedOutStub(origin: nil, transport: StubTransport(routes: [:])))
}

#Preview("Signed in") {
  RootView(session: .stub(transport: StubTransport(routes: [:])))
}
