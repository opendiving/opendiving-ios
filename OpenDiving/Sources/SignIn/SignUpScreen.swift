import OpenDivingKit
import SwiftUI

/// A code or a link redeemed for an address with no account: the address, the name and the
/// username the account starts with, and the web's sentence on the terms. The picture is set in
/// Settings afterwards.
struct SignUpScreen: View {
  let flow: SignInFlow
  let email: String?
  let origin: ServerOrigin?
  @ScaledMetric(relativeTo: .body) private var spinnerSide: CGFloat = 24

  var body: some View {
    Form {
      Section {
        Text(SignInFlow.signUpNote)
      }
      if let email {
        Section("Email") {
          Text(email)
            .foregroundStyle(.secondary)
        }
      }
      field(.name, prompt: "Enter your full name")
      field(.username, prompt: "Choose a username")
      if let error = flow.signUpError {
        Section {
          Label(error, systemImage: "exclamationmark.triangle")
            .foregroundStyle(Color.danger)
        }
      }
      Section {
        Button {
          Task { await flow.signUp() }
        } label: {
          // Held in place under the spinner, so the button keeps its size.
          Text(SignInFlow.signUpButton)
            .bold()
            .opacity(flow.isSigningUp ? 0 : 1)
            .overlay {
              if flow.isSigningUp {
                BubbleSpinner(side: spinnerSide, style: .white)
              }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .tint(.brandCoral)
        .controlSize(.large)
        .disabled(!flow.canSignUp)
        .accessibilityValue(flow.isSigningUp ? SignInFlow.signingUp : "")
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
      } footer: {
        if let origin {
          Text(Self.terms(origin))
            .tint(Color(.secondaryLabel))
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
            .padding(.top, 8)
        }
      }
      Section {
        Button("Use a different email") { flow.useDifferentEmail() }
          .accentRow()
          .disabled(flow.isSigningUp)
      }
    }
    .disabled(flow.isSigningUp)
    .navigationTitle(SignInFlow.signUpTitle)
  }

  private func field(_ field: AccountFieldModel.Field, prompt: String) -> some View {
    Section {
      TextField(prompt, text: text(field))
        .textContentType(field == .name ? .name : .username)
        .textInputAutocapitalization(field == .name ? .words : .never)
        .autocorrectionDisabled()
    } header: {
      Text(field == .name ? "Full name" : field.label)
    } footer: {
      if let problem = flow.signUpProblem(field) {
        FieldMessage(problem)
      }
    }
  }

  private func text(_ field: AccountFieldModel.Field) -> Binding<String> {
    switch field {
    case .name: Binding(get: { flow.signUpName }, set: { flow.setSignUpName($0) })
    case .username: Binding(get: { flow.signUpUsername }, set: { flow.setSignUpUsername($0) })
    }
  }

  /// The sentence, each document an underlined link to the server's page, which opens in the
  /// browser.
  static func terms(_ origin: ServerOrigin) -> AttributedString {
    SignInFlow.signUpTerms(origin).reduce(into: AttributedString()) { line, run in
      var part = AttributedString(run.text)
      if let url = run.url {
        part.link = url
        part.underlineStyle = .single
      }
      line += part
    }
  }
}

#Preview {
  let session = Session.signedOutStub(transport: StubTransport(routes: [:]))
  NavigationStack {
    SignUpScreen(flow: SignInFlow(session: session), email: "sam@example.com", origin: .flagship)
  }
}
