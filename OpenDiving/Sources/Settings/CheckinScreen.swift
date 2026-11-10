import OpenDivingKit
import SwiftUI

/// *Settings* → *Check-in*.
struct CheckinScreen: View {
  @Environment(Session.self) private var session

  var body: some View {
    ManagedOnTheWebView(
      title: SettingsSection.checkin.title, icon: SettingsSection.checkin.icon,
      message: "Your check-in details are changed on the web."
    )
    .followsAccount(session)
  }
}

#Preview {
  NavigationStack {
    CheckinScreen()
  }
  .environment(Session.stub(transport: StubTransport(routes: [:])))
}
