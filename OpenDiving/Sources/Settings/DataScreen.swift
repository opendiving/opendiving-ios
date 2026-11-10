import OpenDivingKit
import SwiftUI

/// *Settings* → *Data*.
struct DataScreen: View {
  @Environment(Session.self) private var session

  var body: some View {
    ManagedOnTheWebView(
      title: SettingsSection.data.title, icon: SettingsSection.data.icon,
      message: "Storage and data export are on the web."
    )
    .followsAccount(session)
  }
}

#Preview {
  NavigationStack {
    DataScreen()
  }
  .environment(Session.stub(transport: StubTransport(routes: [:])))
}
