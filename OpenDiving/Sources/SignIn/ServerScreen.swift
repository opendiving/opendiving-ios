import OpenDivingKit
import SwiftUI

/// The server field, *Continue*, and *Forget this server* for any typed origin the phone holds
/// something for — whether or not that server still answers.
struct ServerScreen: View {
  let flow: SignInFlow
  @State private var forgetting: ServerOrigin?

  var body: some View {
    Form {
      if let notice = flow.notice {
        Section {
          Label(notice, systemImage: "checkmark.circle")
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
        Text("Server")
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
      if let origin = flow.forgettableOrigin {
        Section {
          Button("Forget this server", role: .destructive) { forgetting = origin }
        } footer: {
          Text(ForgetServerConfirmation.heldMessage(origin))
        }
      }
    }
    .navigationTitle("Choose a server")
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

#Preview {
  let session = Session.signedOutStub(origin: nil, transport: StubTransport(routes: [:]))
  NavigationStack {
    ServerScreen(flow: SignInFlow(session: session))
  }
}
