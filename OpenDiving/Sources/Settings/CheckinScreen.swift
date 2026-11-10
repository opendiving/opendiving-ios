import OpenDivingKit
import SwiftUI

/// *Settings* → *Check-in*.
struct CheckinScreen: View {
  @Environment(Session.self) private var session

  var body: some View {
    List {
      ManagedOnTheWebSection(
        section: .checkin, sentence: "Your check-in details are changed on the web.")
    }
    .navigationTitle("Check-in")
    .followsAccount(session)
  }
}

#Preview {
  NavigationStack {
    CheckinScreen()
  }
  .environment(Session.stub(transport: StubTransport(routes: [:])))
}
