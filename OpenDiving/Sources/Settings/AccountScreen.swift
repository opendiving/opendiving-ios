import OpenDivingKit
import SwiftUI

/// *Settings* → *Account*: the account's name, username and email.
struct AccountScreen: View {
  @Environment(Session.self) private var session

  var body: some View {
    List {
      Section {
        if let user = session.user {
          LabeledContent("Name", value: user.name)
          LabeledContent("Username", value: user.username)
          LabeledContent("Email", value: user.email)
        } else {
          HStack {
            BubbleSpinner()
            Text("Loading your account…")
          }
          .foregroundStyle(.secondary)
        }
      }
      ManagedOnTheWebSection(
        section: .account, sentence: "Your name, username and email are changed on the web.")
    }
    .navigationTitle("Account")
    .followsAccount(session)
  }
}

#Preview {
  NavigationStack {
    AccountScreen()
  }
  .environment(Session.stub(transport: StubTransport(routes: [:])))
}
