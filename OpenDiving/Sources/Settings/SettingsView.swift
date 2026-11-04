import OpenDivingKit
import SwiftUI

/// The *Settings* tab: the server card, with signing out and the servers screen, the account
/// as read-only rows, and the app.
struct SettingsView: View {
  @Environment(Session.self) private var session
  @Environment(SignInFlow.self) private var signIn

  var body: some View {
    NavigationStack {
      SettingsList(session: session, signIn: signIn)
        .navigationTitle("Settings")
    }
  }
}

private struct SettingsList: View {
  @State private var model: SettingsModel

  init(session: Session, signIn: SignInFlow) {
    _model = State(initialValue: SettingsModel(session: session, signIn: signIn))
  }

  var body: some View {
    List {
      if let card = model.card {
        ServerCard(content: card) {
          Button("Sign out") { Task { await model.signOut() } }
            .disabled(model.isWorking)
          if let origin = model.signIn.signingOut {
            SigningOutRow(origin: origin) { model.signIn.stopWaiting() }
          }
          if let error = model.error {
            Label(error, systemImage: "exclamationmark.triangle")
              .foregroundStyle(.red)
          }
          NavigationLink("Change server") {
            // A notice from an earlier visit is not this one's; one set while here, by a page
            // pushed over the list, is.
            ServerScreen(flow: model.signIn)
              .onFirstAppear { model.signIn.dismissNotice() }
          }
          .disabled(model.isWorking)
        }
      }
      Section {
        if let user = model.session.user {
          LabeledContent("Name", value: user.name)
          LabeledContent("Username", value: user.username)
          LabeledContent("Email", value: user.email)
        } else {
          HStack {
            ProgressView()
            Text("Loading your account…")
          }
          .foregroundStyle(.secondary)
        }
        LabeledContent("Units", value: model.unitsLabel)
      } header: {
        Text("Account")
      } footer: {
        Text("Units are changed on the web.")
      }
      Section("App") {
        LabeledContent("Version", value: Self.appVersion)
      }
    }
    .task { await model.load() }
  }

  private static var appVersion: String {
    let info = Bundle.main.infoDictionary
    let version = info?["CFBundleShortVersionString"] as? String ?? "Unknown"
    guard let build = info?["CFBundleVersion"] as? String else { return version }
    return version + " (" + build + ")"
  }
}

#Preview {
  let session = Session.stub(transport: StubTransport(routes: [:]))
  SettingsView()
    .environment(session)
    .environment(SignInFlow(session: session))
}
