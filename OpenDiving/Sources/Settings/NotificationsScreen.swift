import OpenDivingKit
import SwiftUI

/// *Settings* → *Notifications*: a switch per scheduled email, each saving on change.
struct NotificationsScreen: View {
  @Environment(Session.self) private var session

  var body: some View {
    NotificationsList(session: session)
      .navigationTitle("Notifications")
      .followsAccount(session)
  }
}

private struct NotificationsList: View {
  @State private var model: NotificationsModel

  init(session: Session) {
    _model = State(initialValue: NotificationsModel(session: session))
  }

  var body: some View {
    List {
      Section {
        ForEach(model.preferences) { preference in
          Toggle(
            isOn: Binding(
              get: { model.isOn(preference) },
              set: { on in Task { await model.set(preference, on) } })
          ) {
            Text(preference.label)
            Text(preference.description)
          }
        }
        .disabled(model.write.isSaving)
      } header: {
        Text("Choose what we email you about.")
      } footer: {
        if let failure = model.write.failure {
          FieldMessage(failure)
        }
      }
    }
  }
}

#Preview {
  NavigationStack {
    NotificationsScreen()
  }
  .environment(Session.stub(transport: StubTransport(routes: [:])))
}
