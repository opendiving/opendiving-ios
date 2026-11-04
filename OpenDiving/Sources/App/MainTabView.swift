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
    Self.styleTabBar
  }

  /// The brand coral, #FF7F50 as on the web, as the bar draws it. Its glass darkens the selected
  /// tab in the light appearance and lightens it in the dark, so the colour passed is offset each
  /// way — in the light, red past sRGB's range — for what lands on screen to be #FF7F50.
  static let coral = UIColor { traits in
    traits.userInterfaceStyle == .dark
      ? UIColor(red: 0.976, green: 0.474, blue: 0.29, alpha: 1)
      : UIColor(red: 1.041, green: 0.531, blue: 0.349, alpha: 1)
  }

  /// Bold labels, and the selected tab in coral — the tab bar's alone, so the rest of the app
  /// keeps its accent. Set on the appearance proxy, before the bar exists, because the tab
  /// bar reads no SwiftUI font. The size is fixed, as the system's own labels are: the bar's height
  /// is, and Dynamic Type reaches it through the Large Content Viewer instead.
  static let styleTabBar: Void = {
    let font = UIFont.systemFont(ofSize: 10, weight: .bold)
    let appearance = UITabBarAppearance()
    appearance.configureWithDefaultBackground()
    for layout in [
      appearance.stackedLayoutAppearance, appearance.inlineLayoutAppearance,
      appearance.compactInlineLayoutAppearance,
    ] {
      layout.normal.titleTextAttributes[.font] = font
      layout.selected.titleTextAttributes = [.font: font, .foregroundColor: coral]
      layout.selected.iconColor = coral
    }
    UITabBar.appearance().standardAppearance = appearance
    UITabBar.appearance().scrollEdgeAppearance = appearance
    UITabBar.appearance().tintColor = coral
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
    .environment(
      DiveComputerDownloads {
        DiveComputerModel(
          session: session, inbox: InboxModel(session: session),
          link: LibDCDiveComputerLink(manager: nil, defaults: .standard),
          generator: DiveComputerView.generator)
      })
}
