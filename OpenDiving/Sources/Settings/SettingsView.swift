import OpenDivingKit
import SwiftUI

/// The *Settings* tab: the server and the build it runs, the account as read-only rows, the
/// servers screen, signing out and forgetting the server.
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
  @State private var computers: DiveComputersListModel
  @State private var forgetting: ServerOrigin?

  init(session: Session, signIn: SignInFlow) {
    _model = State(initialValue: SettingsModel(session: session, signIn: signIn))
    _computers = State(initialValue: DiveComputersListModel(session: session))
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
        NavigationLink("Change server") {
          // A notice from an earlier visit is not this one's.
          ServerScreen(flow: model.signIn)
            .onAppear { model.signIn.dismissNotice() }
        }
        .disabled(model.isWorking)
        Button("Sign out") { Task { await model.signOut() } }
          .disabled(model.isWorking)
        Button("Forget this server", role: .destructive) { forgetting = model.origin }
          .disabled(model.isWorking)
        if let origin = model.signIn.signingOut {
          SigningOutRow(origin: origin) { model.signIn.stopWaiting() }
        }
        if let error = model.error {
          Label(error, systemImage: "exclamationmark.triangle")
            .foregroundStyle(.red)
        }
      } footer: {
        Text(KeptText.settingsFooter)
      }
      Section("App") {
        NavigationLink {
          DiveComputersListView(model: computers)
        } label: {
          LabeledContent(DiveComputerText.settingsRow, value: "\(computers.computers.count)")
        }
        LabeledContent("Version", value: Self.appVersion)
      }
    }
    .task { await model.load() }
    .onAppear { computers.reload() }
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
