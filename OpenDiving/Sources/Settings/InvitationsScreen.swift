import OpenDivingKit
import SwiftUI

/// *Settings* → *Invitations*.
struct InvitationsScreen: View {
  @Environment(Session.self) private var session

  var body: some View {
    ManagedOnTheWebView(
      title: SettingsSection.invitations.title, icon: SettingsSection.invitations.icon,
      message: "Invitations are sent on the web."
    )
    .followsAccount(session)
  }
}

#Preview {
  NavigationStack {
    InvitationsScreen()
  }
  .environment(Session.stub(transport: StubTransport(routes: [:])))
}
