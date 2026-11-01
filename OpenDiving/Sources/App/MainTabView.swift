import OpenDivingKit
import SwiftUI

enum AppTab: Hashable {
  case dives, trips, sites, cards, settings
}

/// The signed-in shell. Every tab is shown at all times: the selection must always name a
/// visible tab, which the iOS 27 SDK can crash on otherwise.
struct MainTabView: View {
  @State private var selection = AppTab.dives

  init() {
    Self.boldLabels
  }

  /// The labels a weight heavier than the system's. Set on the appearance proxy, before the bar
  /// exists, because the tab bar reads no SwiftUI font; scaled, so Dynamic Type still moves it.
  static let boldLabels: Void = {
    let font = UIFontMetrics(forTextStyle: .caption2)
      .scaledFont(for: .systemFont(ofSize: 10, weight: .semibold))
    let appearance = UITabBarAppearance()
    appearance.configureWithDefaultBackground()
    for layout in [
      appearance.stackedLayoutAppearance, appearance.inlineLayoutAppearance,
      appearance.compactInlineLayoutAppearance,
    ] {
      layout.normal.titleTextAttributes[.font] = font
      layout.selected.titleTextAttributes[.font] = font
    }
    UITabBar.appearance().standardAppearance = appearance
    UITabBar.appearance().scrollEdgeAppearance = appearance
  }()

  var body: some View {
    TabView(selection: $selection) {
      Tab("Dives", image: Icon.tabDive.rawValue, value: AppTab.dives) {
        DivesView()
      }
      Tab("Trips", image: Icon.tabLuggage.rawValue, value: AppTab.trips) {
        TripsView()
      }
      Tab("Sites", image: Icon.tabDiveSite.rawValue, value: AppTab.sites) {
        SitesView()
      }
      Tab("Cards", image: Icon.tabIdCard.rawValue, value: AppTab.cards) {
        CardsView()
      }
      Tab("Settings", image: Icon.tabSettings.rawValue, value: AppTab.settings) {
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
