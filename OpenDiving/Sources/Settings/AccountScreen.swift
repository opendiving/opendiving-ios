import OpenDivingKit
import SwiftUI

/// *Settings* → *Account*: the profile picture, the name and the username, saved together; the
/// email, changed through a confirmation link; and deleting the account.
struct AccountScreen: View {
  @Environment(Session.self) private var session

  var body: some View {
    AccountList(session: session)
      .navigationTitle("Account")
      .followsAccount(session)
  }
}

private struct AccountList: View {
  @State private var form: AccountFormModel
  @State private var email: EmailChangeModel

  init(session: Session) {
    _form = State(initialValue: AccountFormModel(session: session))
    _email = State(initialValue: EmailChangeModel(session: session))
  }

  var body: some View {
    List {
      if form.isLoaded {
        AccountProfileSection(model: form)
        AccountEmailSection(model: email)
        Section {
          NavigationLink {
            DeleteAccountScreen()
          } label: {
            Text("Delete my account")
              .foregroundStyle(Color.danger)
          }
        } header: {
          Text("Danger zone")
        } footer: {
          Text(AccountDeletionModel.summary)
        }
      } else {
        HStack {
          BubbleSpinner()
          Text("Loading your account…")
        }
        .foregroundStyle(.secondary)
      }
    }
  }
}

/// The profile picture, the name and the username, and the one *Save* that sends whichever
/// changed.
private struct AccountProfileSection: View {
  let model: AccountFormModel

  var body: some View {
    Section {
      PictureFieldView(model: model.picture)
      VStack(alignment: .leading, spacing: 4) {
        LabeledContent("Name") {
          TextField("Name", text: Binding(get: { model.name }, set: { model.setName($0) }))
            .textContentType(.name)
            .multilineTextAlignment(.trailing)
        }
        if let problem = model.nameProblem {
          FieldMessage(problem)
        }
      }
      VStack(alignment: .leading, spacing: 4) {
        LabeledContent("Username") {
          TextField(
            "Username", text: Binding(get: { model.username }, set: { model.setUsername($0) })
          )
          .textContentType(.username)
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()
          .multilineTextAlignment(.trailing)
        }
        if let problem = model.usernameProblem {
          FieldMessage(problem)
        }
      }
      if model.isSaving {
        HStack {
          BubbleSpinner()
          Text("Saving…")
        }
        .foregroundStyle(.secondary)
      } else {
        Button("Save") { Task { await model.save() } }
          .accentRow()
          .disabled(!model.canSave)
      }
    } header: {
      Text("Profile")
    } footer: {
      if let failure = model.write.failure ?? model.pictureFailure {
        FieldMessage(failure)
      } else if model.saved {
        Text(AccountFormModel.savedMessage)
      }
    }
    .disabled(model.isSaving)
  }
}

/// The current address, and a new one sent a confirmation link.
private struct AccountEmailSection: View {
  let model: EmailChangeModel

  var body: some View {
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
    } header: {
      Text("Email address")
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
}

#Preview {
  let session = Session.stub(transport: StubTransport(routes: [:]))
  NavigationStack {
    AccountScreen()
  }
  .environment(session)
  .environment(SignInFlow(session: session))
}
