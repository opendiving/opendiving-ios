import OpenDivingKit
import SwiftUI
import Testing
import UIKit

@testable import OpenDiving

/// The dive list and the dive page, hosted under a session over a stub transport: each
/// asks the API for what it draws.
@MainActor
struct DiveScreensTests {
  private let diveID = "01a20000-0000-7000-8000-000000000001"

  private func host(_ view: some View, session: Session) -> UIWindow? {
    guard
      let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first
    else { return nil }
    let window = UIWindow(windowScene: scene)
    window.rootViewController = UIHostingController(rootView: view.environment(session))
    window.makeKeyAndVisible()
    window.layoutIfNeeded()
    return window
  }

  /// Waits up to two seconds for `transport` to have been sent `route`.
  private func waitFor(_ route: String, on transport: StubTransport) async -> Bool {
    for _ in 0..<200 {
      if transport.requests.map(StubTransport.routeKey).contains(route) { return true }
      try? await Task.sleep(for: .milliseconds(10))
    }
    return false
  }

  @Test func theListAsksForTheFirstPage() async throws {
    let transport = StubTransport(routes: [
      "GET dives": .json(
        #"{"data":[],"total_count":0,"has_more":false,"page":1,"items_per_page":50}"#)
    ])
    let window = host(DivesView(), session: Session.stub(transport: transport))
    defer { window?.isHidden = true }
    #expect(window != nil)
    #expect(await waitFor("GET dives", on: transport))
    let query = transport.requests.first?.url?.query ?? ""
    #expect(query.contains("page=1"))
    #expect(query.contains("items_per_page=50"))
  }

  @Test func thePageAsksForTheDiveThenItsNeighbours() async throws {
    let transport = StubTransport(routes: [
      "GET dive/\(diveID)": .json(DivePreviewData.dive)
    ])
    let window = host(
      NavigationStack { DiveDetailView(diveUUID: DivePreviewData.diveUUID) },
      session: Session.stub(transport: transport))
    defer { window?.isHidden = true }
    #expect(await waitFor("GET dive/\(diveID)/neighbors", on: transport))
  }
}
