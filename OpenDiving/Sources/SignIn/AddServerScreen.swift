import OpenDivingKit
import SwiftUI

/// The field and *Continue* for a server not on the list, and *Forget this server* for any
/// typed origin the phone holds something for — whether or not that server still answers.
/// The servers screen pushes it.
struct AddServerScreen: View {
  let flow: SignInFlow
  @State private var forgetting: ServerOrigin?

  var body: some View {
    Form {
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
    Task { await flow.continueToServer() }
  }
}

#Preview {
  let session = Session.signedOutStub(origin: nil, transport: StubTransport(routes: [:]))
  NavigationStack {
    AddServerScreen(flow: SignInFlow(session: session))
  }
  .environment(session)
}
