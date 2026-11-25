import OpenDivingKit
import SwiftUI

/// The profile's *Dives*: what is waiting to sync, the dives of a download until they land,
/// newest first, then what a renumber would tidy, and the logbook, newest first as the server
/// orders it, a page at a time — the pages the phone has shown first, from its copy.
struct ProfileDives: View {
  let list: PagedList<DiveListItem>
  /// What a renumber would tidy, the numbering card's sentence; nil, with no card, for a tidy log.
  let numbering: String?
  let units: UnitSystem
  @Environment(DiveComputerEngine.self) private var engine: DiveComputerEngine?

  var body: some View {
    let rows = engine?.downloadRows(units: units) ?? []
    LazyVStack(spacing: 12) {
      // What is waiting to sync, and the dives on their way, show however the list stands:
      // offline with nothing kept, the first page is a minute away.
      PendingSection(countsDownloads: Self.pendingCountsDownloads)
      // Above the logbook rather than among its dives by date, which a paged list cannot place
      // without every page.
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
        if let numbering {
          DiveNumberingCard(description: numbering)
        }
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
  let session = DivePreviewData.session
  let list = ProfileDives.list(session)
  let numbering = DiveNumberingModel(session: session)
  NavigationStack {
    ScrollView {
      ProfileDives(list: list, numbering: numbering.description, units: .metric)
        .padding()
    }
    .task { await list.load() }
    .task { await numbering.load() }
  }
  .environment(session)
  .environment(InboxModel(session: session))
  .environment(OutboxModel(session: session))
}
