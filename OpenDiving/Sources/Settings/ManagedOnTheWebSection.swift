import OpenDivingKit
import SwiftUI

/// What a section the phone does not edit yet shows: one sentence, and its page on the web.
struct ManagedOnTheWebSection: View {
  let section: SettingsSection
  let sentence: String

  @Environment(Session.self) private var session

  var body: some View {
    Section {
      if let origin = session.state.origin {
        Link("Open on the web", destination: section.webURL(on: origin))
          .accentRow()
      }
    } footer: {
      Text(sentence)
    }
  }
}

#Preview {
  List {
    ManagedOnTheWebSection(
      section: .data, sentence: "Storage and data export are on the web.")
  }
  .environment(Session.stub(transport: StubTransport(routes: [:])))
}
