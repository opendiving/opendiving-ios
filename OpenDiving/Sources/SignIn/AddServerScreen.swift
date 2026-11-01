import OpenDivingKit
import SwiftUI

/// The field and *Continue* for a server not on the list, and *Forget this server* for any
/// typed origin the phone holds something for — whether or not that server still answers.
/// The servers screen pushes it, and it closes once the server is chosen.
struct AddServerScreen: View {
  let flow: SignInFlow
  @State private var forgetting: ServerOrigin?
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    Form {
      // What the *Forget* below did, as the servers screen shows it.
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
      Section {
        TextField(
          "https://dive.example.org",
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
        Text("Server")
      } footer: {
        Text("The address of an OpenDiving server: one you run yourself works the same way.")
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
      if let origin = flow.forgettableOrigin,
        !flow.savedServers.contains(where: { $0.origin == origin })
      {
        Section {
          Button("Forget this server", role: .destructive) { forgetting = origin }
            .disabled(flow.signingOut != nil)
        } footer: {
          Text(ForgetServerConfirmation.heldMessage(origin))
        }
      }
    }
    .navigationTitle("Add server")
    .forgetServerConfirmation(origin: $forgetting) { origin in
      Task { await flow.forget(origin) }
    }
  }

  private func proceed() {
    Task {
      // Signed out, the screen beneath is replaced by the sign-in, and this one would stay
      // pushed on top of it.
      if await flow.continueToServer() { dismiss() }
    }
  }
}

#Preview {
  let session = Session.signedOutStub(origin: nil, transport: StubTransport(routes: [:]))
  NavigationStack {
    AddServerScreen(flow: SignInFlow(session: session))
  }
  .environment(session)
}
