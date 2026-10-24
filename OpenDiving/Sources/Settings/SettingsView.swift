import OpenDivingKit
import SwiftUI

/// The *Settings* tab: the server and the build it runs, the account as read-only rows, and
/// signing out, changing server and forgetting the server.
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
  @State private var forgetting: ServerOrigin?

  init(session: Session, signIn: SignInFlow) {
    _model = State(initialValue: SettingsModel(session: session, signIn: signIn))
  }

  var body: some View {
    List {
      Section("Server") {
        LabeledContent("Address", value: model.origin?.description ?? "None")
        LabeledContent("Version", value: model.serverVersion)
        LabeledContent("Commit", value: model.serverCommit)
        if let origin = model.origin, !origin.isEncrypted {
          Label("The connection to this server is not encrypted.", systemImage: "lock.open")
            .foregroundStyle(.orange)
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
      Section {
        Button("Sign out") { Task { await model.signOut() } }
        Button("Change server") { Task { await model.changeServer() } }
        Button("Forget this server", role: .destructive) { forgetting = model.origin }
        if model.isWorking {
          ProgressView()
        }
        if let error = model.error {
          Label(error, systemImage: "exclamationmark.triangle")
            .foregroundStyle(.red)
        }
      } footer: {
        Text(KeptText.settingsFooter)
      }
      .disabled(model.isWorking)
      Section("App") {
        LabeledContent("Version", value: Self.appVersion)
      }
    }
    .task { await model.load() }
    .forgetServerConfirmation(origin: $forgetting) { _ in
      Task { await model.forget() }
    }
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
