import OpenDivingKit
import SwiftUI

/// The profile's *Dives*: what is waiting to sync, the dives of a download until they land,
/// newest first, then the logbook, newest first as the server orders it, a page at a time — the
/// pages the phone has shown first, from its copy.
struct ProfileDives: View {
  let list: PagedList<DiveListItem>
  let units: UnitSystem
  @Environment(DiveComputerEngine.self) private var engine: DiveComputerEngine?

  var body: some View {
    let rows = engine?.downloadRows(units: units) ?? []
    LazyVStack(spacing: 12) {
      // What is waiting to sync, and the dives on their way, show however the list stands:
      // offline with nothing kept, the first page is a minute away.
      PendingSection(countsDownloads: Self.pendingCountsDownloads)
      ForEach(rows) { row in
        DownloadRowView(row: row)
      }
      switch list.phase {
      case .idle, .loading:
        EmptyOrErrorView(status: .loading)
          .padding(.top, 32)
      case .failed(let error):
        EmptyOrErrorView(status: .failed(message: error.message)) {
          Task { await list.refresh() }
        }
      case .loaded where Self.showsEmpty(dives: list.items.count, rows: rows.count):
        EmptyOrErrorView(
          status: .empty(
            icon: .dive, title: "No dives logged yet",
            message:
              "No dives yet. Log one with the button below, or bring them in from your dive "
              + "computer with the button at the top left."
          )
        )
      case .loaded:
        if let lastUpdated = list.lastUpdated {
          LastUpdatedLine(date: lastUpdated)
        }
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
    }
  }
}

extension ProfileDives {
  /// The waiting-to-sync card has no line for the downloaded dives, which stand as rows here.
  static let pendingCountsDownloads = false

  /// *No dives logged yet* yields to a dive on its way.
  static func showsEmpty(dives: Int, rows: Int) -> Bool { dives == 0 && rows == 0 }

  /// The logbook's list, over the account's copy of the pages it has shown.
  static func list(_ session: Session) -> PagedList<DiveListItem> {
    PagedList(session: session, cache: .dives) { client, page, itemsPerPage in
      try await client.dives(page: page, itemsPerPage: itemsPerPage)
    }
  }
}

#Preview {
  let list = ProfileDives.list(DivePreviewData.session)
  NavigationStack {
    ScrollView {
      ProfileDives(list: list, units: .metric)
        .padding()
    }
    .task { await list.load() }
  }
  .environment(DivePreviewData.session)
  .environment(InboxModel(session: DivePreviewData.session))
  .environment(OutboxModel(session: DivePreviewData.session))
}
