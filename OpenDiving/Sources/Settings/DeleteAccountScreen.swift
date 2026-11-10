import OpenDivingKit
import SwiftUI

/// *Delete my account*, pushed from *Account*: what goes, a copy of it first, and the username
/// typed back before the delete is offered. The screen goes with the session once it lands, and
/// the sign-in screens show the goodbye.
struct DeleteAccountScreen: View {
  @Environment(SignInFlow.self) private var signIn

  var body: some View {
    DeleteAccountForm(signIn: signIn)
      .navigationTitle("Delete account")
      .navigationBarTitleDisplayMode(.inline)
  }
}

private struct DeleteAccountForm: View {
  @State private var model: AccountDeletionModel

  init(signIn: SignInFlow) {
    _model = State(initialValue: AccountDeletionModel(signIn: signIn))
  }

  var body: some View {
    Form {
      Section {
        Text(AccountDeletionModel.warning)
      }
      Section {
        if model.exports.downloading != nil {
          HStack {
            BubbleSpinner()
            Text("Preparing…")
          }
          .foregroundStyle(.secondary)
        } else {
          Button("Download my data first") { model.downloadFirst() }
            .accentRow()
            .disabled(model.exports.isBusy || model.isDeleting)
        }
      } footer: {
        if let failure = model.exports.failure {
          FieldMessage(failure.message)
        } else {
          Text(ExportFormat.archive.summary)
        }
      }
      Section {
        TextField(
          "Username", text: Binding(get: { model.typed }, set: { model.setTyped($0) })
        )
        .textContentType(.none)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .disabled(model.isDeleting)
      } header: {
        if let username = model.username {
          Text("Type \(Text(username).bold()) to confirm")
            .textCase(nil)
        }
      }
      Section {
        if model.isDeleting {
          HStack {
            BubbleSpinner()
            Text("Deleting…")
          }
          .foregroundStyle(.secondary)
        } else {
          Button(role: .destructive) {
            Task { await model.delete() }
          } label: {
            Text("Delete my account")
              .bold()
              .frame(maxWidth: .infinity)
          }
          .dangerRow()
          .disabled(!model.canDelete)
        }
      } footer: {
        if let failure = model.failure {
          FieldMessage(failure)
        }
      }
    }
    .sharesExports(model.exports)
  }
}

#Preview {
  let session = Session.stub(transport: StubTransport(routes: [:]))
  NavigationStack {
    DeleteAccountScreen()
  }
  .environment(session)
  .environment(SignInFlow(session: session))
}
