import OpenDivingKit
import SwiftUI

/// A run of a paged list's dives as cards, each opening the dive's page, and the last of
/// them asking the list for its next page.
struct DiveCardLinks: View {
  let items: [DiveListItem]
  let list: PagedList<DiveListItem>
  let units: UnitSystem

  var body: some View {
    VStack(spacing: 12) {
      ForEach(items) { item in
        NavigationLink {
          DiveDetailView(diveUUID: item.id)
        } label: {
          DiveCardView(content: DiveCardContent.dive(item, units: units))
        }
        .buttonStyle(.plain)
        .onAppear { Task { await list.loadMore(after: item) } }
      }
    }
  }
}

#Preview {
  NavigationStack {
    DiveCardLinks(
      items: [],
      list: PagedList(session: Session.stub(transport: StubTransport(routes: [:]))) {
        client, page, itemsPerPage in
        try await client.dives(page: page, itemsPerPage: itemsPerPage)
      },
      units: .metric)
  }
}
