import OpenDivingKit
import SwiftUI

/// The saved servers to switch to or forget, the field and *Continue* for another, and
/// *Forget this server* for any typed origin the phone holds something for — whether or not
/// that server still answers. Signed out it is a step of the sign-in; signed in, Settings
/// pushes it.
struct ServerScreen: View {
  let flow: SignInFlow
  @State private var forgetting: ServerOrigin?

  var body: some View {
    let servers = flow.savedServers
    Form {
      if let notice = flow.notice {
        Section {
          Label(notice, systemImage: "info.circle")
        }
      }
      if let origin = flow.signingOut {
        Section {
          SigningOutRow(origin: origin) { flow.stopWaiting() }
        }
      }
      if !servers.isEmpty {
        Section {
          ForEach(servers) { server in
            Button {
              flow.switchTo(server.origin)
            } label: {
              SavedServerLabel(server: server)
            }
            .disabled(flow.signingOut != nil)
            .swipeActions {
              Button("Forget", role: .destructive) { forgetting = server.origin }
            }
          }
        } header: {
          Text("Saved servers")
        } footer: {
          Text(KeptText.savedServersFooter)
        }
      }
      Section {
        TextField(
          "https://opendiving.app",
          text: Binding(get: { flow.serverText }, set: { flow.setServerText($0) })
        )
        .keyboardType(.URL)
        .textContentType(.URL)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .submitLabel(.continue)
        .onSubmit(proceed)
        .disabled(flow.isValidating)
        .accessibilityLabel("Server address")
      } header: {
        Text(servers.isEmpty ? "Server" : "Another server")
      } footer: {
        Text(
          "The OpenDiving server your account is on. The project runs https://opendiving.app,"
            + " and a server you run yourself works the same way.")
      }
      if let problem = flow.serverProblem {
        Section {
          Label(problem.message, systemImage: "exclamationmark.triangle")
            .foregroundStyle(.red)
        }
      }
      Section {
        Button(action: proceed) {
          if flow.isValidating {
            HStack {
              ProgressView()
              Text("Connecting…")
            }
          } else {
            Text("Continue")
          }
        }
        .disabled(flow.isValidating)
      }
      if let origin = flow.forgettableOrigin, !servers.contains(where: { $0.origin == origin }) {
        Section {
          Button("Forget this server", role: .destructive) { forgetting = origin }
            .disabled(flow.signingOut != nil)
        } footer: {
          Text(ForgetServerConfirmation.heldMessage(origin))
        }
      }
    }
    .navigationTitle("Servers")
    .toolbar {
      if flow.canCancelServerChange {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { flow.cancelServerChange() }
        }
      }
    }
    .forgetServerConfirmation(origin: $forgetting) { origin in
      Task { await flow.forget(origin) }
    }
  }

  private func proceed() {
    Task { await flow.continueToServer() }
  }
}

/// A saved server's address, whether the phone is signed in there, and a check on the active
/// one.
private struct SavedServerLabel: View {
  let server: SavedServer

  var body: some View {
    HStack {
      VStack(alignment: .leading) {
        Text(server.origin.description)
          .foregroundStyle(.primary)
        Text(server.status)
          .font(.footnote)
          .foregroundStyle(.secondary)
      }
      Spacer()
      if server.isActive {
        Image(systemName: "checkmark")
          .foregroundStyle(.tint)
          .accessibilityLabel("Current server")
      }
    }
  }
}

#Preview {
  let session = Session.signedOutStub(origin: nil, transport: StubTransport(routes: [:]))
  NavigationStack {
    ServerScreen(flow: SignInFlow(session: session))
  }
  .environment(session)
}
