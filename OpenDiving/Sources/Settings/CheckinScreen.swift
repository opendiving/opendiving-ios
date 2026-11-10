import OpenDivingKit
import SwiftUI

/// *Settings* → *Check-in*: the details a dive shop's desk asks for, in three groups that each
/// save alone. The sheet they print on is the profile's *Cards*.
struct CheckinScreen: View {
  @Environment(Session.self) private var session

  var body: some View {
    CheckinForm(session: session)
      .navigationTitle(SettingsSection.checkin.title)
      .followsAccount(session)
  }
}

private struct CheckinForm: View {
  @State private var model: CheckinDetailsModel

  init(session: Session) {
    _model = State(initialValue: CheckinDetailsModel(session: session))
  }

  var body: some View {
    Form {
      Section {
        if model.details == nil {
          if let failure = model.loadFailure, !model.isLoading {
            VStack(alignment: .leading, spacing: 8) {
              FieldMessage("Your check-in details didn’t load. \(failure)")
              Button("Try again") { Task { await model.load() } }
                .accentRow()
                .buttonStyle(.borderless)
            }
          } else {
            HStack {
              BubbleSpinner()
              Text("Loading your check-in details…")
            }
            .foregroundStyle(.secondary)
          }
        }
      } header: {
        Text(
          "What a dive shop asks for at the desk. Fill in what you want to hand over; anything"
            + " you leave empty is left off your check-in summary."
        )
        .textCase(nil)
      }
      if model.details != nil {
        CheckinAboutSection(model: model)
        CheckinPoliciesSection(model: model)
        CheckinContactsSection(model: model)
      }
    }
    .task {
      await model.load()
      await model.followRoute()
    }
  }
}

#Preview {
  NavigationStack {
    CheckinScreen()
  }
  .environment(Session.stub(transport: StubTransport(routes: [:])))
}
