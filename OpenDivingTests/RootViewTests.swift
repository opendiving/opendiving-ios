import OpenDivingKit
import SwiftUI
import Testing
import UIKit

@testable import OpenDiving

@MainActor
struct RootViewTests {
  @Test func rootViewConstructs() {
    let host = UIHostingController(rootView: RootView(session: .device()))
    host.loadViewIfNeeded()
    host.view.layoutIfNeeded()
    #expect(host.view != nil)
  }

  @Test func signedInTheRootIsTheSitesMapUnderTheInjectedSession() async throws {
    let window = try Self.window(
      RootView(session: .stub(transport: StubTransport(routes: [:]))))
    defer { window.isHidden = true }

    #expect(await Self.title(in: window) == "Sites")
  }

  @Test func withNoServerTheRootIsTheServerScreen() async throws {
    let window = try Self.window(
      RootView(session: .signedOutStub(origin: nil, transport: StubTransport(routes: [:]))))
    defer { window.isHidden = true }

    #expect(await Self.title(in: window) == "Servers")
  }

  @Test func signedOutOfAServerTheRootIsSigningInThere() async throws {
    let window = try Self.window(
      RootView(session: .signedOutStub(transport: StubTransport(routes: [:]))))
    defer { window.isHidden = true }

    #expect(await Self.title(in: window) == "Sign In")
  }

  private static func window(_ root: some View) throws -> UIWindow {
    let scene = try #require(
      UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
    let window = UIWindow(windowScene: scene)
    window.rootViewController = UIHostingController(rootView: root)
    window.makeKeyAndVisible()
    window.layoutIfNeeded()
    return window
  }

  /// The title of the first navigation stack's top screen, once SwiftUI has set one.
  private static func title(in window: UIWindow) async -> String? {
    for _ in 0..<50 {
      window.layoutIfNeeded()
      if let title = navigationController(in: window.rootViewController)?
        .topViewController?.navigationItem.title
      {
        return title
      }
      try? await Task.sleep(for: .milliseconds(20))
    }
    return nil
  }

  private static func navigationController(in controller: UIViewController?)
    -> UINavigationController?
  {
    guard let controller else { return nil }
    if let navigation = controller as? UINavigationController { return navigation }
    for child in controller.children {
      if let navigation = navigationController(in: child) { return navigation }
    }
    return nil
  }
}
