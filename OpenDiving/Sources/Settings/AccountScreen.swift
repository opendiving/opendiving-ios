import OpenDivingKit
import SwiftUI

/// *Settings* → *Account*, also opened by the profile's picture: the profile picture with
/// *Edit photo*; the name, the username and the email, a row each opening its own screen; and
/// deleting the account.
struct AccountScreen: View {
  @Environment(Session.self) private var session

  var body: some View {
    AccountList(session: session)
      .navigationTitle("Account")
      .followsAccount(session)
  }
}

private struct AccountList: View {
  let session: Session
  @State private var write: AccountWrite
  @State private var picture: PictureFieldModel
  @State private var email: EmailChangeModel

  init(session: Session) {
    self.session = session
    _write = State(initialValue: AccountWrite(session: session))
    _picture = State(initialValue: PictureFieldModel(kind: .avatar, session: session))
    _email = State(initialValue: EmailChangeModel(session: session))
  }

  var body: some View {
    List {
      if session.user != nil {
        Section {
          AccountPictureHeader(model: picture)
        }
        .listRowBackground(Color.clear)
        Section {
          fieldRow(.name, icon: .user)
          fieldRow(.username, icon: .atSign)
          NavigationLink {
            EmailChangeScreen(model: email)
          } label: {
            row("Email", value: email.currentEmail ?? "", icon: .mail)
          }
        }
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

  private func fieldRow(_ field: AccountFieldModel.Field, icon: Icon) -> some View {
    NavigationLink {
      AccountFieldScreen(field: field, write: write)
    } label: {
      row(
        field.label, value: AccountFieldModel.shown(field, write: write, session: session),
        icon: icon)
    }
  }

  /// The value beside its symbol, which stands in for the label on screen and not to VoiceOver.
  private func row(_ label: String, value: String, icon: Icon) -> some View {
    Label {
      Text(value)
    } icon: {
      Image(icon)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(label)
    .accessibilityValue(value)
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
