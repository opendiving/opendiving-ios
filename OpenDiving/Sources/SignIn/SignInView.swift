import OpenDivingKit
import SwiftUI

/// Choosing a server and signing in with an email code: everything the app shows signed out.
/// Reads the session and the sign-in flow the root injects.
struct SignInView: View {
  @Environment(Session.self) private var session
  @Environment(SignInFlow.self) private var flow
  @State private var showsSheet = false

  var body: some View {
    NavigationStack {
      screen
    }
    // A sheet, never a push: the Cards view owns its own navigation stack.
    .sheet(isPresented: $showsSheet) {
      CardsView()
        .environment(session)
    }
  }

  @ViewBuilder private var screen: some View {
    switch flow.step {
    case .server:
      ServerScreen(flow: flow)
    case .email:
      if let origin = flow.origin {
        EmailScreen(flow: flow, origin: origin) { showsSheet = true }
      }
    case .code(let email, _):
      CodeScreen(flow: flow, email: email)
    case .onboardingRequired(let email, _):
      OutcomeScreen(
        title: "Finish signing up on the web", systemImage: "person.crop.circle.badge.questionmark",
        message: OutcomeScreen.onboardingMessage(email: email, origin: flow.origin),
        origin: flow.origin
      ) { flow.useDifferentEmail() }
    case .deletionPending(let email, let purgeAfter):
      OutcomeScreen(
        title: "This account is scheduled for deletion", systemImage: "trash",
        message: OutcomeScreen.deletionMessage(
          email: email, purgeAfter: purgeAfter, origin: flow.origin),
        origin: flow.origin
      ) { flow.useDifferentEmail() }
    }
  }
}

#Preview("No server") {
  let session = Session.signedOutStub(origin: nil, transport: StubTransport(routes: [:]))
  SignInView()
    .environment(session)
    .environment(SignInFlow(session: session))
}

#Preview("Signing in") {
  let session = Session.signedOutStub(transport: StubTransport(routes: [:]))
  SignInView()
    .environment(session)
    .environment(SignInFlow(session: session))
}
