import OpenDivingKit
import SwiftUI

/// The six-digit code from the email. It submits itself on the sixth digit; *Resend* comes
/// back after the cooldown.
struct CodeScreen: View {
  let flow: SignInFlow
  let email: String

  var body: some View {
    Form {
      Section {
        Text(
          "We sent a sign-in link and a six-digit code to \(email). Either one signs you in —"
            + " they expire in 30 minutes and can only be used once. The link signs you in on"
            + " the web; the code signs you in here.")
      }
      Section {
        CodeField(code: Binding(get: { flow.code }, set: { flow.setCode($0) }))
          .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
        if flow.isVerifying {
          HStack {
            ProgressView()
            Text("Checking your code…")
          }
          .foregroundStyle(.secondary)
        }
        if let error = flow.codeError {
          Label(error, systemImage: "exclamationmark.triangle")
            .foregroundStyle(.red)
        }
      } header: {
        Text("Enter the code from the email")
      }
      Section {
        if let message = flow.resendMessage {
          Label(message, systemImage: "checkmark.circle")
        }
        TimelineView(.periodic(from: .now, by: 1)) { context in
          Button(flow.resendLabel(at: context.date)) {
            Task { await flow.resendCode() }
          }
          .disabled(flow.isResending || flow.resendSecondsLeft(at: context.date) > 0)
        }
        Button("Use a different email") { flow.useDifferentEmail() }
      }
    }
    .navigationTitle("Check your email")
    .onChange(of: flow.code) {
      if flow.isCodeComplete {
        Task { await flow.submitCode() }
      }
    }
  }
}

#Preview {
  let session = Session.signedOutStub(transport: StubTransport(routes: [:]))
  NavigationStack {
    CodeScreen(flow: SignInFlow(session: session), email: "diver@example.com")
  }
}
