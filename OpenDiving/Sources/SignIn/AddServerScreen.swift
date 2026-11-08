import OpenDivingKit
import SwiftUI

/// The field and *Continue* for a server not on the list, and *Forget this server* for any
/// typed origin the phone holds something for — whether or not that server still answers.
/// The servers screen pushes it, and it closes once the server is chosen.
struct AddServerScreen: View {
  let flow: SignInFlow
  @State private var forgetting: ServerOrigin?
  @Environment(\.dismiss) private var dismiss

  @FocusState private var focused: Bool

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
        // Verbatim, because a literal address is parsed into a link and drawn in the link colour.
        TextField(
          "Server address",
          text: Binding(get: { flow.serverText }, set: { flow.setServerText($0) }),
          prompt: Text(verbatim: "https://dive.example.org")
        )
        .keyboardType(.URL)
        .textContentType(.URL)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .submitLabel(.continue)
        .onSubmit(proceed)
        .disabled(flow.isValidating)
        .focused($focused)
      } header: {
        Text("Server").focusesOnTap($focused)
      } footer: {
        Text("The address of an OpenDiving API server.")
      }
      if let problem = flow.serverProblem {
        Section {
          Label(problem.message, systemImage: "exclamationmark.triangle")
            .foregroundStyle(Color.danger)
        }
      }
      Section {
        Button(action: proceed) {
          if flow.isValidating {
            HStack {
              BubbleSpinner()
              Text("Connecting…")
            }
          } else {
            Text("Continue")
          }
        }
        .accentRow()
        .disabled(flow.isValidating)
      }
      if let origin = flow.forgettableOrigin,
        !flow.savedServers.contains(where: { $0.origin == origin })
      {
        Section {
          Button("Forget this server", role: .destructive) { forgetting = origin }
            .dangerRow()
            .disabled(flow.signingOut != nil)
        } footer: {
          Text(ForgetServerConfirmation.heldMessage(origin))
        }
      }
    }
    .background(TapEndsTyping())
    .navigationTitle("Add Server")
    .forgetServerConfirmation(origin: $forgetting) { origin in
      Task { await flow.forget(origin) }
    }
  }

  private func proceed() {
    Task {
      // A new server starts the stack over by itself; the one already active changes nothing,
      // and would leave this screen open.
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
