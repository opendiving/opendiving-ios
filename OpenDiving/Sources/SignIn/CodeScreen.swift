import OpenDivingKit
import SwiftUI

/// The six-digit code from the email, headed by who invited the diver while a connect link is
/// held, or by that it is no longer active when the request for the email found it reset. It
/// submits itself on the sixth digit; *Resend* comes back after the cooldown.
struct CodeScreen: View {
  let flow: SignInFlow
  let email: String

  var body: some View {
    Form {
      if case .from(let name, let picture) = flow.invitation {
        Section {
          InvitationHeader(flow: flow, name: name, picture: picture, showsNote: false)
        }
        .listRowBackground(Color.clear)
      } else if flow.invitation == .gone {
        InvitationGoneSection()
      }
      Section {
        // True whether or not this phone opens the server's links in the app, which the app
        // cannot tell.
        Text(
          "We sent a sign-in link and a six-digit code to \(email). Either one signs you in —"
            + " they expire in 30 minutes and can only be used once. The code signs you in here;"
            + " the link does too where it opens in this app, and on the web where it opens in"
            + " the browser.")
      }
      Section {
        CodeField(code: Binding(get: { flow.code }, set: { flow.setCode($0) }))
          .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
        if flow.isVerifying {
          HStack {
            BubbleSpinner()
            Text("Checking your code…")
          }
          .foregroundStyle(.secondary)
        }
        if let error = flow.codeError {
          Label(error, systemImage: "exclamationmark.triangle")
            .foregroundStyle(Color.danger)
        }
      } header: {
        Text("Enter the code from the email")
      }
      Section {
        if let message = flow.resendMessage {
          NoticeRow(notice: message, systemImage: "checkmark.circle")
        }
        TimelineView(.periodic(from: .now, by: 1)) { context in
          Button(flow.resendLabel(at: context.date)) {
            Task { await flow.resendCode() }
          }
          .accentRow()
          .disabled(flow.isResending || flow.resendSecondsLeft(at: context.date) > 0)
        }
        Button("Use a different email") { flow.useDifferentEmail() }
          .accentRow()
      }
    }
    .navigationTitle("Check Your Email")
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
