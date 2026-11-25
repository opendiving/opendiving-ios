import OpenDivingKit
import SwiftUI

/// *Settings*, pushed from the profile: a row per section in the web's order, the app — its
/// appearance and its version — the server card with the servers screen, and last signing out.
struct SettingsView: View {
  @Environment(Session.self) private var session
  @Environment(SignInFlow.self) private var signIn

  var body: some View {
    SettingsList(session: session, signIn: signIn)
      .navigationTitle("Settings")
  }
}

private struct SettingsList: View {
  @State private var model: SettingsModel

  init(session: Session, signIn: SignInFlow) {
    _model = State(initialValue: SettingsModel(session: session, signIn: signIn))
  }

  var body: some View {
    List {
      Section {
        ForEach(model.sections) { section in
          NavigationLink {
            Self.screen(section)
          } label: {
            Label(row: section.title, icon: section.icon)
          }
        }
      }
      .disabled(model.isWorking)
      Section("App") {
        NavigationLink {
          AppearanceScreen()
        } label: {
          Label(row: "Appearance", icon: .monitor)
        }
        LabeledContent {
          Text(Self.appVersion)
        } label: {
          Label(row: "Version", icon: .dive)
        }
      }
      if let card = model.card {
        ServerCard(content: card) {
          NavigationLink("Change server") {
            // A notice from an earlier visit is not this one's; one set while here, by a page
            // pushed over the list, is.
            ServerScreen(flow: model.signIn)
              .onFirstAppear { model.signIn.dismissNotice() }
          }
          .disabled(model.isWorking)
        }
      }
      if let origin = model.signIn.signingOut {
        Section {
          SigningOutRow(origin: origin) { model.signIn.stopWaiting() }
        }
      }
      Section {
        // Drawn as DeleteRecordSection draws a form's delete, without its confirmation: signing
        // out loses nothing the next sign-in does not bring back.
        Button(role: .destructive) {
          Task { await model.signOut() }
        } label: {
          Text("Sign out")
            .bold()
            .frame(maxWidth: .infinity)
        }
        .dangerRow()
        .disabled(model.isWorking)
        .needsServer()
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 0, trailing: 16))
      } footer: {
        if let error = model.error {
          FieldMessage(error)
        }
      }
      .listSectionSpacing(.compact)
    }
    .task { await model.load() }
    .followsAccount(model.session)
  }

  @ViewBuilder
  private static func screen(_ section: SettingsSection) -> some View {
    switch section {
    case .account: AccountScreen()
    case .checkin: CheckinScreen()
    case .authentication: AuthenticationScreen()
    case .data: DataScreen()
    case .notifications: NotificationsScreen()
    case .preferences: PreferencesScreen()
    }
  }

  private static var appVersion: String {
    let info = Bundle.main.infoDictionary
    let version = info?["CFBundleShortVersionString"] as? String ?? "Unknown"
    guard let build = info?["CFBundleVersion"] as? String else { return version }
    return version + " (" + build + ")"
  }
}

#Preview {
  let session = Session.stub(transport: StubTransport(routes: [:]))
  NavigationStack {
    SettingsView()
  }
  .environment(session)
  .environment(SignInFlow(session: session))
  .environment(AppearanceModel(defaults: .standard))
}
