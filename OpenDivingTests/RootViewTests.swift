import OpenDivingKit
import SwiftUI
import Testing
import UIKit

@testable import OpenDiving

@MainActor
struct RootViewTests {
  @Test func rootViewConstructs() {
    let host = UIHostingController(rootView: RootView())
    host.loadViewIfNeeded()
    host.view.layoutIfNeeded()
    #expect(host.view != nil)
  }

  @Test func theTabsShowUnderTheInjectedSession() throws {
    let scene = try #require(
      UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
    let window = UIWindow(windowScene: scene)
    window.rootViewController = UIHostingController(rootView: RootView())
    window.makeKeyAndVisible()
    defer { window.isHidden = true }
    window.layoutIfNeeded()

    let tabBar = try #require(Self.tabBarController(in: window.rootViewController))
    #expect(
      tabBar.tabBar.items?.compactMap(\.title) == ["Dives", "Trips", "Sites", "Cards", "Settings"])
  }

  private static func tabBarController(in controller: UIViewController?) -> UITabBarController? {
    guard let controller else { return nil }
    if let tabs = controller as? UITabBarController { return tabs }
    for child in controller.children {
      if let tabs = tabBarController(in: child) { return tabs }
    }
    return nil
  }
}
