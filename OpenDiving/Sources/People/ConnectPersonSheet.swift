import OpenDivingKit
import SwiftUI

/// The person form *Add* opens from *Added you*: headed by the account it connects to, over the
/// choice of a new person or one of the diver's people who is not connected yet, the new person's
/// fields, and what saving shows the other diver.
struct ConnectPersonSheet: View {
  let account: AddedYouRow
  @Environment(Session.self) private var session

  var body: some View {
    NavigationStack {
      ConnectPersonForm(model: ConnectPersonModel(session: session, account: account))
    }
  }
}

/// The form itself, in the navigation stack of whatever opens it: *Added you*'s sheet, or a
/// connect link's.
struct ConnectPersonForm: View {
  @State var model: ConnectPersonModel
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    Form {
      Section {
        ConnectedAccountHead(
          picture: model.connection.picture, name: model.connection.name,
          username: model.connection.username)
      }
      if !model.candidates.isEmpty {
        Section {
          Picker("Person", selection: $model.choice) {
            Text("A new person").tag(ConnectPersonModel.Choice.new)
            ForEach(model.candidates) { person in
              Text(person.name).tag(ConnectPersonModel.Choice.existing(person.uuid))
            }
          }
          .tint(Color.accentText)
        } footer: {
          Text("Connect someone you already have, and the dives that name them stay as they are.")
        }
      }
      if model.choice == .new {
        Section {
          TextBox(
            label: "Name *", placeholder: "e.g. Alex M.", text: $model.values.name,
            message: model.message("name"), contentType: .name)
          TextBox(
            label: "Email", text: $model.values.email, message: model.message("email"),
            keyboard: .emailAddress, verbatim: true)
          TextBox(
            label: "Phone", text: $model.values.phone, message: model.message("phone"),
            keyboard: .phonePad)
          NotesField(
            placeholder: "How you met, what they dive, anything worth remembering...",
            text: $model.values.notes, error: model.message("notes"))
        }
      }
      Section {
        Text(model.reveals)
          .font(.footnote)
          .foregroundStyle(.secondary)
        if let failure = model.failure {
          Text(failure).foregroundStyle(Color.danger)
        }
      }
    }
    .background(TapEndsTyping())
    .navigationTitle("Add Person")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button("Cancel") { dismiss() }
      }
      ToolbarItem(placement: .confirmationAction) {
        if model.isSaving {
          BubbleSpinner()
        } else {
          ToolbarConfirmButton(title: "Add") {
            Task { if await model.save() { dismiss() } }
          }
          .needsServer()
        }
      }
    }
  }
}

#Preview {
  ConnectPersonSheet(
    account: AddedYouRow(uuid: UUID(), name: "Robin Diver", username: "robin")
  )
  .environment(Session.stub(transport: StubTransport(routes: [:])))
}
