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

  /// The brand coral, #FF7F50 as on the web, as the bar draws a selected label. Its glass mixes in
  /// what lies behind it, darkening the label in the light appearance and lightening it in the
  /// dark, so the colour passed is offset each way — in the light, red past sRGB's range — to land
  /// on #FF7F50 over a white backdrop in the light and a black one in the dark.
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

  /// The selected icon is coloured rather than tinted: the glass mixes its backdrop into a tinted
  /// icon pixel by pixel, which washes it out over a map, and leaves an original-rendered one alone.
  /// A label has no such rendering mode.
  private func tabLabel(_ title: LocalizedStringKey, _ icon: Icon, for tab: AppTab) -> some View {
    Label {
      Text(title)
    } icon: {
      if selection == tab, let symbol = UIImage(named: icon.rawValue) {
        Image(uiImage: symbol.withTintColor(UIColor(.brandCoral), renderingMode: .alwaysOriginal))
      } else {
        Image(icon.rawValue)
      }
    }
  }

  var body: some View {
    TabView(selection: $selection) {
      Tab(value: AppTab.dives) {
        DivesView()
      } label: {
        tabLabel("Dives", .tabDive, for: .dives)
      }
      Tab(value: AppTab.trips) {
        TripsView()
      } label: {
        tabLabel("Trips", .tabLuggage, for: .trips)
      }
      Tab(value: AppTab.sites) {
        SitesView()
      } label: {
        tabLabel("Sites", .tabDiveSite, for: .sites)
      }
      Tab(value: AppTab.cards) {
        CardsView()
      } label: {
        tabLabel("Cards", .tabIdCard, for: .cards)
      }
      Tab(value: AppTab.settings) {
        SettingsView()
      } label: {
        tabLabel("Settings", .tabSettings, for: .settings)
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
