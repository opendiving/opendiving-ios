import OpenDivingKit
import SwiftUI

/// Asks `list` for its next page when it scrolls into a lazy stack's reach: placed after a
/// list's rows where those rows are not themselves lazy. A new identity per page, so it
/// fires again for the next one even if it never left the stack's window.
struct PageEndTrigger<Item: Codable & Sendable>: View {
  let list: PagedList<Item>

  var body: some View {
    Color.clear
      .frame(height: 0)
      .accessibilityHidden(true)
      .id(list.items.count)
      .onAppear { Task { await list.loadMore() } }
  }
}

#Preview {
  PageEndTrigger(
    list: PagedList(session: Session.stub(transport: StubTransport(routes: [:]))) {
      client, page, itemsPerPage in
      try await client.dives(page: page, itemsPerPage: itemsPerPage)
    })
}
