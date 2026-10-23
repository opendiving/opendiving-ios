import OpenDivingKit
import SwiftUI

/// Signing in to the active server: the email field, and the three things reachable signed
/// out — the cached check-in sheet, another server, and forgetting this one.
struct EmailScreen: View {
  let flow: SignInFlow
  let origin: ServerOrigin
  let showSheet: () -> Void
  @State private var forgetting: ServerOrigin?

  var body: some View {
    Form {
      if let notice = flow.notice {
        Section {
          Label(notice, systemImage: "exclamationmark.triangle")
            .foregroundStyle(.red)
        }
      }
      Section {
        LabeledContent("Server", value: origin.description)
        if !origin.isEncrypted {
          Label("The connection to this server is not encrypted.", systemImage: "lock.open")
            .foregroundStyle(.orange)
        }
      }
      Section {
        TextField(
          "you@example.com", text: Binding(get: { flow.email }, set: { flow.setEmail($0) })
        )
        .keyboardType(.emailAddress)
        .textContentType(.emailAddress)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .submitLabel(.send)
        .onSubmit(send)
        .accessibilityLabel("Email")
      } header: {
        Text("Email")
      } footer: {
        Text("We'll email you a six-digit sign-in code.")
      }
      if let error = flow.emailError {
        Section {
          Label(error, systemImage: "exclamationmark.triangle")
            .foregroundStyle(.red)
        }
      }
      Section {
        Button(action: send) {
          if flow.isRequestingCode {
            HStack {
              ProgressView()
              Text("Sending…")
            }
          } else {
            Text("Send code")
          }
        }
        .disabled(!flow.canSendCode)
      }
      Section {
        ForEach(flow.signedOutEntries) { entry in
          switch entry {
          case .checkInSheet:
            Button(action: showSheet) {
              Label("Your check-in sheet", systemImage: "person.text.rectangle")
            }
          case .differentServer:
            Button {
              flow.useDifferentServer()
            } label: {
              Label("Use a different server", systemImage: "server.rack")
            }
          case .forgetServer:
            Button(role: .destructive) {
              forgetting = origin
            } label: {
              Label("Forget this server", systemImage: "trash")
            }
          }
        }
      } footer: {
        Text(
          "Your check-in sheet stays on this phone after you sign out, until you forget the server."
        )
      }
    }
    .navigationTitle("Sign in")
    .forgetServerConfirmation(origin: $forgetting) { origin in
      Task { await flow.forget(origin) }
    }
  }

  private func send() {
    Task { await flow.sendCode() }
  }
}

#Preview {
  let session = Session.signedOutStub(
    origin: ServerOrigin("http://192.168.1.20:8000"), transport: StubTransport(routes: [:]))
  NavigationStack {
    EmailScreen(flow: SignInFlow(session: session), origin: session.state.origin!) {}
  }
}
