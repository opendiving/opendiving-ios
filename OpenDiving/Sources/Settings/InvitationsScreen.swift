import OpenDivingKit
import SwiftUI

/// *Settings* → *Invitations*.
struct InvitationsScreen: View {
  @Environment(Session.self) private var session

  var body: some View {
    List {
      ManagedOnTheWebSection(section: .invitations, sentence: "Invitations are sent on the web.")
    }
    .navigationTitle("Invitations")
    .followsAccount(session)
  }
}

#Preview {
  NavigationStack {
    InvitationsScreen()
  }
  .environment(Session.stub(transport: StubTransport(routes: [:])))
}
