import OpenDivingKit
import SwiftUI

/// The name or the username on a screen of its own: the field, why it would be refused, and
/// *Save*, which goes back to *Account* once the change has landed.
struct AccountFieldScreen: View {
  let field: AccountFieldModel.Field
  /// *Account*'s, so a save whose read fails still shows there.
  let write: AccountWrite
  @Environment(Session.self) private var session

  var body: some View {
    AccountFieldForm(model: AccountFieldModel(field: field, write: write, session: session))
      .navigationTitle(field.label)
      .navigationBarTitleDisplayMode(.inline)
  }
}

private struct AccountFieldForm: View {
  @State private var model: AccountFieldModel
  @FocusState private var focused: Bool
  @Environment(\.dismiss) private var dismiss

  init(model: AccountFieldModel) {
    _model = State(initialValue: model)
  }

  var body: some View {
    Form {
      Section {
        TextField(
          model.field.label, text: Binding(get: { model.text }, set: { model.setText($0) })
        )
        .textContentType(model.field == .name ? .name : .username)
        .textInputAutocapitalization(model.field == .name ? .words : .never)
        .autocorrectionDisabled()
        .submitLabel(.done)
        .focused($focused)
        .onSubmit(save)
      } footer: {
        if let failure = model.failure {
          FieldMessage(failure)
        } else if let problem = model.problem {
          FieldMessage(problem)
        }
      }
    }
    .disabled(model.isSaving)
    .toolbar {
      ToolbarItem(placement: .confirmationAction) {
        if model.isSaving {
          BubbleSpinner()
        } else {
          ToolbarConfirmButton(title: "Save", action: save)
            .disabled(!model.canSave)
        }
      }
    }
    .onAppear { focused = true }
  }

  private func save() {
    Task { if await model.save() { dismiss() } }
  }
}

#Preview {
  let session = Session.stub(transport: StubTransport(routes: [:]))
  NavigationStack {
    AccountFieldScreen(field: .username, write: AccountWrite(session: session))
  }
  .environment(session)
}
