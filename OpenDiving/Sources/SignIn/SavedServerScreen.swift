import OpenDivingKit
import SwiftUI

/// One saved server, opened from the servers screen: its card, the account signed in there,
/// when it was last used, signing out and forgetting it.
struct SavedServerScreen: View {
  @State private var model: SavedServerModel
  @State private var forgetting: ServerOrigin?
  @Environment(\.dismiss) private var dismiss

  init(flow: SignInFlow, origin: ServerOrigin) {
    _model = State(initialValue: SavedServerModel(origin: origin, signIn: flow))
  }

  var body: some View {
    Form {
      ServerCard(content: model.card)
      Section {
        if let email = model.signedInAs {
          LabeledContent("Signed in as", value: email)
        } else {
          LabeledContent("Account", value: "Signed out")
        }
        LabeledContent("Last used", value: model.lastUsed)
      }
      Section {
        if model.isSignedIn {
          Button("Sign out") { Task { await model.signOut() } }
            .disabled(model.isWorking)
        }
        if model.canForget {
          Button("Forget this server", role: .destructive) { forgetting = model.origin }
            .foregroundStyle(Color.danger)
            .disabled(model.isWorking)
        }
        if let origin = model.signIn.signingOut {
          SigningOutRow(origin: origin) { model.signIn.stopWaiting() }
        }
        if let error = model.error {
          Label(error, systemImage: "exclamationmark.triangle")
            .foregroundStyle(Color.danger)
        }
      }
    }
    .navigationTitle("Server")
    .navigationBarTitleDisplayMode(.inline)
    .task { await model.load() }
    .forgetServerConfirmation(origin: $forgetting) { _ in
      Task {
        if await model.forget() { dismiss() }
      }
    }
  }
}

#Preview {
  let session = Session.stub(transport: StubTransport(routes: [:]))
  NavigationStack {
    SavedServerScreen(flow: SignInFlow(session: session), origin: session.state.origin!)
  }
  .environment(session)
}
