import OpenDivingKit
import SwiftUI

/// More's *Dive Sites*: every dive site of the account's, pinned or not, most recently dived
/// first, each opening on the map — the pages the phone has shown first, from its copy.
struct YourDiveSitesView: View {
  @Environment(Session.self) private var session

  var body: some View {
    YourDiveSitesContent(list: .yourDiveSites(session))
  }
}

extension YourDiveSitesView {
  static let title = "Dive Sites"
  static let empty = "You have no dive sites yet."

  /// What a failed first page says: offline, that the list shows once it can be read.
  static func failure(_ error: APIError) -> String {
    error.isUnreachable ? OfflineText.yourDiveSitesNotShown : error.message
  }
}

private struct YourDiveSitesContent: View {
  @State var list: PagedList<DiveSiteSearchRow>
  @Environment(Session.self) private var session

  var body: some View {
    ScrollView {
      LazyVStack(spacing: 12) {
        switch list.phase {
        case .idle, .loading:
          EmptyOrErrorView(status: .loading)
            .padding(.top, 32)
        case .failed(let error):
          EmptyOrErrorView(status: .failed(message: YourDiveSitesView.failure(error))) {
            Task { await list.refresh() }
          }
        case .loaded where list.items.isEmpty:
          EmptyOrErrorView(
            status: .empty(icon: .diveSite, title: YourDiveSitesView.empty, message: nil))
        case .loaded:
          if let lastUpdated = list.lastUpdated {
            LastUpdatedLine(date: lastUpdated)
          }
          ForEach(list.items) { row in
            if let content = YourDiveSiteRowContent(row, units: session.units),
              let site = content.siteUUID
            {
              NavigationLink {
                SiteMapView(siteUUID: site)
              } label: {
                YourDiveSiteRow(content: content)
              }
              .buttonStyle(.plain)
              .onAppear { Task { await list.loadMore(after: row) } }
            }
          }
          LoadMoreFooter(list: list)
        }
      }
      .padding()
    }
    .background(Color.pageBackground)
    .bubbleRefreshable { await list.refresh() }
    .navigationTitle(YourDiveSitesView.title)
    .navigationBarTitleDisplayMode(.inline)
    .task { await list.show(following: session) }
  }
}

/// One site: its name, its facts, the diver's dives there, a proposal waiting on it, and a
/// Commons record's mark and credit.
private struct YourDiveSiteRow: View {
  let content: YourDiveSiteRowContent

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(content.title)
        .font(.body.weight(.medium))
        .foregroundStyle(Color.primary)
      FactsLine(facts: content.facts)
      if let figures = content.figures {
        Text(figures)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      if content.isWaitingForReview {
        BadgeView(DiveSiteProposalSummary.waitingForReview, style: .outline)
      }
      if content.isCommons {
        HStack(spacing: 8) {
          DiveSiteMarkBadge(mark: .commons)
          if let credit = content.credit {
            AttributionLine(credits: [credit])
          }
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(12)
    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    .contentShape(Rectangle())
  }
}

#Preview {
  NavigationStack {
    YourDiveSitesView()
  }
  .environment(Session.stub(transport: StubTransport(routes: [:])))
}
