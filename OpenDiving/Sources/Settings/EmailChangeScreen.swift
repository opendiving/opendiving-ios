import OpenDivingKit
import SwiftUI

/// The current address, and a new one sent a confirmation link.
struct EmailChangeScreen: View {
  /// *Account*'s, so where the last link went still shows on coming back.
  let model: EmailChangeModel

  var body: some View {
    Form {
      Section {
        LabeledContent("Current email", value: model.currentEmail ?? "")
        TextField(
          "New email", text: Binding(get: { model.newEmail }, set: { model.setNewEmail($0) })
        )
        .keyboardType(.emailAddress)
        .textContentType(.emailAddress)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .onSubmit { Task { await model.send() } }
        if model.isSending {
          HStack {
            BubbleSpinner()
            Text("Sending…")
          }
          .foregroundStyle(.secondary)
        } else {
          Button("Send confirmation link") { Task { await model.send() } }
            .accentRow()
            .disabled(!model.canSend)
        }
      } footer: {
        VStack(alignment: .leading, spacing: 8) {
          if let failure = model.failure {
            FieldMessage(failure)
          }
          if let sent = model.sentMessage {
            Text(sent)
          }
          Text("Changing your email requires confirming the new address first.")
        }
      }
      .disabled(model.isSending)
    }
    .navigationTitle("Email")
    .navigationBarTitleDisplayMode(.inline)
  }
}

#Preview {
  let session = Session.stub(transport: StubTransport(routes: [:]))
  NavigationStack {
    EmailChangeScreen(model: EmailChangeModel(session: session))
  }
}
