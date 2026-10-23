import OpenDivingKit
import SwiftUI

/// What the window shows — the server and sign-in screens, or the signed-in shell — and where
/// the one session, and the sign-in flow Settings reaches back into, are injected.
struct RootView: View {
  @State private var session: Session
  @State private var signIn: SignInFlow
  @State private var account: AccountLoader

  init(session: Session = .device()) {
    _session = State(initialValue: session)
    _signIn = State(initialValue: SignInFlow(session: session))
    _account = State(initialValue: AccountLoader(session: session))
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
