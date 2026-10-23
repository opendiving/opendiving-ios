import OpenDivingKit
import SwiftUI

/// The *Dives* tab: the logbook, newest first as the server orders it, a page at a time.
struct DivesView: View {
  @Environment(Session.self) private var session
  @State private var list: PagedList<DiveListItem>?

  var body: some View {
    NavigationStack {
      Group {
        if let list {
          DivesList(list: list, units: session.units)
        } else {
          EmptyOrErrorView(status: .loading)
        }
      }
      .navigationTitle("Dives")
    }
    .task {
      guard list == nil else { return }
      let list = PagedList<DiveListItem>(session: session) { client, page, itemsPerPage in
        try await client.dives(page: page, itemsPerPage: itemsPerPage)
      }
      self.list = list
      await list.load()
    }
  }
}

private struct DivesList: View {
  let list: PagedList<DiveListItem>
  let units: UnitSystem

  var body: some View {
    switch list.phase {
    case .idle, .loading:
      EmptyOrErrorView(status: .loading)
    case .failed(let error):
      EmptyOrErrorView(status: .failed(message: error.message)) {
        Task { await list.refresh() }
      }
    case .loaded where list.items.isEmpty:
      EmptyOrErrorView(
        status: .empty(
          systemImage: "water.waves", title: "No dives logged yet",
          message: "Dives you log on the web appear here.")
      )
      .refreshable { await list.refresh() }
    case .loaded:
      ScrollView {
        LazyVStack(spacing: 12) {
          ForEach(list.items) { item in
            NavigationLink {
              DiveDetailView(diveUUID: item.id)
            } label: {
              DiveCardView(content: .dive(item, units: units))
            }
            .buttonStyle(.plain)
            .task { await list.loadMore(after: item) }
          }
          LoadMoreFooter(list: list)
        }
        .padding()
      }
      .background(Color(.systemGroupedBackground))
      .refreshable { await list.refresh() }
    }
  }
}

#Preview {
  DivesView()
    .environment(DivePreviewData.session)
}
