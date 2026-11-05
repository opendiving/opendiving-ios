import OpenDivingKit
import SwiftUI

/// The *Sites* tab: the diver's dive sites, the most recently dived first and the sites no
/// dive names last, each opening its page, and the `+` that adds one.
struct SitesView: View {
  @Environment(Session.self) private var session

  var body: some View {
    NavigationStack {
      SiteList(session: session)
        .navigationTitle("Sites")
        .toolbar {
          ToolbarItem(placement: .primaryAction) {
            NavigationLink {
              DiveSiteFormView(mode: .create)
            } label: {
              Label("Add dive site", systemImage: "plus")
            }
          }
        }
    }
  }
}

extension SitesView {
  /// The tab's list, over the account's copy of the pages it has shown.
  static func list(_ session: Session) -> PagedList<DiveSiteRead> {
    PagedList(session: session, cache: .diveSites) { client, page, itemsPerPage in
      try await client.diveSites(page: page, itemsPerPage: itemsPerPage)
    }
  }
}

private struct SiteList: View {
  @Environment(Session.self) private var session
  @State private var list: PagedList<DiveSiteRead>

  init(session: Session) {
    _list = State(initialValue: SitesView.list(session))
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
            icon: .diveSite, title: "No dive sites yet",
            message: "Add one with +, or when logging a dive."))
      case .loaded:
        ScrollView {
          LazyVStack(spacing: 12) {
            if let lastUpdated = list.lastUpdated {
              LastUpdatedLine(date: lastUpdated)
            }
            ForEach(list.items) { site in
              VStack(alignment: .leading, spacing: 4) {
                NavigationLink {
                  SiteDetailView(siteUUID: site.uuid)
                } label: {
                  RecordCardView(
                    content: DiveSiteSummary.card(site, units: session.units), icon: .tabDiveSite)
                }
                .buttonStyle(.plain)
                if let attribution = site.attribution {
                  AttributionLine(credits: [attribution])
                }
              }
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
