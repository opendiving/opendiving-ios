import OpenDivingKit
import SwiftUI
import Testing
import UIKit

@testable import OpenDiving

/// The profile's *New*: every record once, the web's create menu first, and every form it opens
/// hosted.
@MainActor
struct CreateMenuTests {
  @Test func theWebsCreateMenuComesFirstRuledOffFromTheRest() {
    #expect(
      CreateItem.sections.flatMap { $0 }.map(\.title) == [
        "New dive", "New trip", "New dive site",
        "New gear", "New gear set", "New certification", "New course", "New person",
        "New contact",
      ])
    #expect(CreateItem.sections.map(\.count) == [3, 6])
  }

  @Test func everyRecordIsInTheMenuOnce() {
    let listed = CreateItem.sections.flatMap { $0 }
    #expect(listed.count == CreateItem.allCases.count)
    #expect(Set(listed) == Set(CreateItem.allCases))
  }

  private func host(_ view: some View) -> UIView? {
    let session = Session.stub(transport: StubTransport(routes: [:]))
    let host = UIHostingController(
      rootView: NavigationStack { view }.environment(session)
        .environment(OutboxModel(session: session)).environment(InboxModel(session: session)))
    host.loadViewIfNeeded()
    host.view.layoutIfNeeded()
    return host.viewIfLoaded
  }

  @Test func theMenuHosts() {
    #expect(host(Color.clear.toolbar { CreateMenu { _ in } }) != nil)
  }

  @Test(arguments: CreateItem.allCases)
  func everyFormHosts(item: CreateItem) {
    #expect(host(item.destination) != nil)
  }
}
