import OpenDivingKit
import SwiftUI

enum AppTab: Hashable {
  case dives, trips, sites, cards, settings
}

/// The signed-in shell. Every tab is shown at all times: the selection must always name a
/// visible tab, which the iOS 27 SDK can crash on otherwise.
struct MainTabView: View {
  @State private var selection = AppTab.dives

  var body: some View {
    TabView(selection: $selection) {
      Tab("Dives", systemImage: "water.waves", value: AppTab.dives) {
        DivesView()
      }
      Tab("Trips", systemImage: "suitcase", value: AppTab.trips) {
        TripsView()
      }
      Tab("Sites", systemImage: "mappin.and.ellipse", value: AppTab.sites) {
        SitesView()
      }
      Tab("Cards", systemImage: "person.text.rectangle", value: AppTab.cards) {
        CardsView()
      }
      Tab("Settings", systemImage: "gearshape", value: AppTab.settings) {
        SettingsView()
      }
    }
  }
}

#Preview {
  let session = Session.stub(transport: StubTransport(routes: [:]))
  MainTabView()
    .environment(session)
    .environment(SignInFlow(session: session))
    .environment(OutboxModel(session: session))
    .environment(InboxModel(session: session))
}
