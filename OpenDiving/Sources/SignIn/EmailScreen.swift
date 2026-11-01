import OpenDivingKit
import SwiftUI

/// Signing in to the active server: the email field, the server card with another server, and
/// what is reachable signed out — the cached check-in sheet, what is waiting to sync for the
/// account last signed in here, and forgetting this server.
struct EmailScreen: View {
  let flow: SignInFlow
  let origin: ServerOrigin
  let showSheet: () -> Void
  let showPending: () -> Void
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
      ServerCard(content: ServerCardContent(origin: origin, health: flow.session.server?.health)) {
        Button("Change server") { flow.useDifferentServer() }
      }
      Section {
        ForEach(flow.signedOutEntries) { entry in
          switch entry {
          case .checkInSheet:
            Button(action: showSheet) {
              Label("Your check-in sheet", icon: .idCard)
            }
          case .waitingToSync:
            Button(action: showPending) {
              Label("Your dives waiting to sync", systemImage: "arrow.triangle.2.circlepath")
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
        Text(KeptText.signedOutFooter(origin))
      }
    }
    .navigationTitle("Sign in")
    .task { await flow.session.loadServerInfo() }
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
    EmailScreen(
      flow: SignInFlow(session: session), origin: session.state.origin!, showSheet: {},
      showPending: {})
  }
  .environment(session)
}
