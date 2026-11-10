import OpenDivingKit
import SwiftUI

/// After the account was deleted on this phone: the day it is erased on, the way back, and what
/// the phone still keeps for the server. It stays until the diver moves on.
struct GoodbyeScreen: View {
  let flow: SignInFlow
  let purgeAfter: String

  var body: some View {
    ContentUnavailableView {
      Label(SignInFlow.goodbyeTitle, systemImage: "calendar.badge.clock")
    } description: {
      VStack(spacing: 12) {
        Text(SignInFlow.goodbyeMessage(purgeAfter: purgeAfter))
        Text(SignInFlow.goodbyeRestore)
        if let origin = flow.origin {
          Text(SignInFlow.goodbyeKept(origin))
            .font(.footnote)
        }
      }
    } actions: {
      Button("Sign in") { flow.useDifferentEmail() }
        .brandProminentButton()
    }
    .navigationTitle("Account Deleted")
  }
}

#Preview {
  let session = Session.signedOutStub(transport: StubTransport(routes: [:]))
  NavigationStack {
    GoodbyeScreen(flow: SignInFlow(session: session), purgeAfter: "Nov 24, 2026")
  }
}
