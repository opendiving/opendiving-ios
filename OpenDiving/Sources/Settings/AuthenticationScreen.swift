import OpenDivingKit
import SwiftUI

/// *Settings* → *Authentication*.
struct AuthenticationScreen: View {
  @Environment(Session.self) private var session

  var body: some View {
    ManagedOnTheWebView(
      title: SettingsSection.authentication.title, icon: SettingsSection.authentication.icon,
      message: "Passkeys, signed-in devices and API keys are managed on the web."
    )
    .followsAccount(session)
  }
}

#Preview {
  NavigationStack {
    AuthenticationScreen()
  }
  .environment(Session.stub(transport: StubTransport(routes: [:])))
}
