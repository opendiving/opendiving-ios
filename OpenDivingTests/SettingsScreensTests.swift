import OpenDivingKit
import SwiftUI
import Testing
import UIKit

@testable import OpenDiving

/// Every section of Settings draws under its title, and the appearance reaches the window.
@MainActor
struct SettingsScreensTests {
  private static let sections: [(String, AnyView)] = [
    ("Account", AnyView(AccountScreen())),
    ("Check-in", AnyView(CheckinScreen())),
    ("Authentication", AnyView(AuthenticationScreen())),
    ("Data", AnyView(DataScreen())),
    ("Notifications", AnyView(NotificationsScreen())),
    ("Preferences", AnyView(PreferencesScreen())),
    ("Invitations", AnyView(InvitationsScreen())),
    ("Appearance", AnyView(AppearanceScreen())),
  ]

  @Test func everySectionDrawsUnderItsTitle() async throws {
    #expect(Self.sections.map(\.0) == SettingsSection.allCases.map(\.title) + ["Appearance"])
    for (title, screen) in Self.sections {
      #expect(try await Self.title(of: NavigationStack { screen }) == title)
    }
  }

  @Test func theAppearanceIsTheWindowsAndFollowsTheChoice() async throws {
    let suite = "SettingsScreensTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let appearance = AppearanceModel(defaults: defaults)
    let window = try Self.window(Text("Logbook").appearanceHost(appearance))
    defer { window.isHidden = true }

    #expect(try await Self.settle(window) { $0.overrideUserInterfaceStyle == .unspecified })
    appearance.choice = .dark
    #expect(try await Self.settle(window) { $0.overrideUserInterfaceStyle == .dark })
    appearance.choice = .system
    #expect(try await Self.settle(window) { $0.overrideUserInterfaceStyle == .unspecified })
  }

  private static func window(_ view: some View) throws -> UIWindow {
    let scene = try #require(
      UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
    let window = UIWindow(windowScene: scene)
    window.rootViewController = UIHostingController(rootView: view)
    window.makeKeyAndVisible()
    return window
  }

  private static func settle(_ window: UIWindow, until done: (UIWindow) -> Bool) async throws
    -> Bool
  {
    for _ in 0..<50 {
      window.layoutIfNeeded()
      if done(window) { return true }
      try await Task.sleep(for: .milliseconds(20))
    }
    return false
  }

  /// Renders `view` in a window signed in, and reads the navigation title it settles on.
  private static func title(of view: some View) async throws -> String? {
    let session = Session.stub(transport: StubTransport(routes: [:]))
    let window = try window(
      view.environment(session).environment(SignInFlow(session: session))
        .environment(AppearanceModel(defaults: .standard)))
    defer { window.isHidden = true }
    var title: String?
    _ = try await settle(window) { window in
      title =
        navigationController(in: window.rootViewController)?.topViewController?
        .navigationItem.title
      return title != nil
    }
    return title
  }

  private static func navigationController(in controller: UIViewController?)
    -> UINavigationController?
  {
    guard let controller else { return nil }
    if let navigation = controller as? UINavigationController { return navigation }
    return controller.children.lazy.compactMap { navigationController(in: $0) }.first
  }
}
