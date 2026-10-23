import OpenDivingKit
import SwiftUI

/// The *Sites* tab: the diver's dive sites, the most recently dived first and the sites no
/// dive names last, each opening its page.
struct SitesView: View {
  @Environment(Session.self) private var session

  var body: some View {
    NavigationStack {
      SiteList(session: session)
        .navigationTitle("Sites")
    }
  }
}

private struct SiteList: View {
  @Environment(Session.self) private var session
  @State private var list: PagedList<DiveSiteRead>

  init(session: Session) {
    _list = State(
      initialValue: PagedList(session: session) { client, page, itemsPerPage in
        try await client.diveSites(page: page, itemsPerPage: itemsPerPage)
      })
  }

  var body: some View {
    Group {
      switch list.phase {
      case .idle, .loading:
        EmptyOrErrorView(status: .loading)
      case .failed(let error):
        EmptyOrErrorView(status: .failed(message: error.message)) {
          Task { await list.load() }
        }
      case .loaded where list.items.isEmpty:
        EmptyOrErrorView(
          status: .empty(
            systemImage: "mappin.and.ellipse", title: "No dive sites yet",
            message: "Dive sites you add on the web appear here."))
      case .loaded:
        ScrollView {
          LazyVStack(spacing: 12) {
            ForEach(list.items) { site in
              NavigationLink {
                SiteDetailView(siteUUID: site.uuid)
              } label: {
                RecordCardView(content: DiveSiteSummary.card(site, units: session.units))
              }
              .buttonStyle(.plain)
              .onAppear { Task { await list.loadMore(after: site) } }
            }
            LoadMoreFooter(list: list)
          }
          .padding()
        }
      }
    }
    .background(Color(.systemGroupedBackground))
    .refreshable { await list.refresh() }
    .task { await list.load() }
  }
}

#Preview {
  SitesView()
    .environment(Session.stub(transport: StubTransport(routes: [:])))
}
