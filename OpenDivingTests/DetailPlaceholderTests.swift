import OpenDivingKit
import SwiftUI
import Testing
import UIKit

@testable import OpenDiving

/// The trip page and the map opened on a site, which other screens push by these initializers,
/// under the session the root injects.
@MainActor
struct DetailPlaceholderTests {
  private func host(_ view: some View) -> UIView? {
    let session = Session.stub(transport: StubTransport(routes: [:]))
    let host = UIHostingController(rootView: NavigationStack { view }.environment(session))
    host.loadViewIfNeeded()
    host.view.layoutIfNeeded()
    return host.viewIfLoaded
  }

  @Test func tripDetailHostsWithAUUID() {
    #expect(host(TripDetailView(tripUUID: UUID())) != nil)
  }

  @Test func siteMapHostsWithAUUID() {
    #expect(host(SiteMapView(siteUUID: UUID())) != nil)
  }
}
