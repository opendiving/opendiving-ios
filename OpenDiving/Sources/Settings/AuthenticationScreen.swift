import OpenDivingKit
import SwiftUI

/// *Settings* → *Authentication*.
struct AuthenticationScreen: View {
  @Environment(Session.self) private var session

  var body: some View {
    List {
      ManagedOnTheWebSection(
        section: .authentication,
        sentence: "Passkeys, signed-in devices and API keys are managed on the web.")
    }
    .navigationTitle("Authentication")
    .followsAccount(session)
  }
}

#Preview {
  NavigationStack {
    AuthenticationScreen()
  }
  .environment(Session.stub(transport: StubTransport(routes: [:])))
}
