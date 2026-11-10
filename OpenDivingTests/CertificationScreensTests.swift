import OpenDivingKit
import SwiftUI
import Testing
import UIKit

@testable import OpenDiving

/// More's certifications: what the list and the page say when they cannot show, and the form
/// hosted on each of its openings.
@MainActor
struct CertificationScreensTests {
  private func host(_ view: some View) -> UIView? {
    let session = Session.stub(transport: StubTransport(routes: [:]))
    let host = UIHostingController(
      rootView: NavigationStack { view }.environment(session)
        .environment(OutboxModel(session: session)).environment(InboxModel(session: session)))
    host.loadViewIfNeeded()
    host.view.layoutIfNeeded()
    return host.viewIfLoaded
  }

  @Test func offlineTheListAndThePageSayTheyShowOnceTheServerCanBeReached() {
    #expect(CertificationListView.failure(.noRoute) == OfflineText.certificationsNotShown)
    #expect(
      CertificationListView.failure(.http(status: 500, message: nil))
        == "Failed to load certifications. Please try again.")
    #expect(CertificationDetailView.failure(.noRoute) == OfflineText.certificationNotShown)
  }

  @Test func theFormHostsOnACreateAndOnARefusedWrite() {
    #expect(host(CertificationFormView(mode: .create)) != nil)
    #expect(host(CertificationFormView(mode: .failed(item: UUID(), record: UUID()))) != nil)
  }
}
