import OpenDivingKit
import SwiftUI

/// *Settings* → *Data*.
struct DataScreen: View {
  @Environment(Session.self) private var session

  var body: some View {
    List {
      ManagedOnTheWebSection(section: .data, sentence: "Storage and data export are on the web.")
    }
    .navigationTitle("Data")
    .followsAccount(session)
  }
}

#Preview {
  NavigationStack {
    DataScreen()
  }
  .environment(Session.stub(transport: StubTransport(routes: [:])))
}
