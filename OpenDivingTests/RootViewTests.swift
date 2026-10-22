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
}
