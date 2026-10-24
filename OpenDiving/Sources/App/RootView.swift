import OpenDivingKit
import SwiftUI

/// What the window shows — the server and sign-in screens, or the signed-in shell — and where
/// the one session, the sign-in flow Settings reaches back into, the inbox and the outbox are
/// injected.
struct RootView: View {
  @State private var session: Session
  @State private var signIn: SignInFlow
  @State private var account: AccountLoader
  @State private var inbox: InboxModel
  @State private var outbox: OutboxModel

  init(session: Session = .device()) {
    let account = AccountLoader(session: session)
    _session = State(initialValue: session)
    _signIn = State(initialValue: SignInFlow(session: session))
    _account = State(initialValue: account)
    _inbox = State(initialValue: InboxModel(session: session))
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
      case .signedIn:
        MainTabView()
      }
    }
    .environment(session)
    .environment(signIn)
    .inboxHost(inbox, session: session)
    .outboxHost(outbox, session: session)
    .task { await account.launch() }
    .onChange(of: session.state) { old, new in
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
