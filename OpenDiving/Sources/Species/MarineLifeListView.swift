import OpenDivingKit
import SwiftUI

/// More's *Marine Life*: every species the diver has logged, most recently seen first, as photo
/// cards each opening the species' page — the pages the phone has shown first, from its copy.
struct MarineLifeListView: View {
  @Environment(Session.self) private var session

  var body: some View {
    MarineLifeListContent(list: .lifeList(session))
  }
}

extension MarineLifeListView {
  static let title = "Marine Life"
  static let description = "Everything you have logged seeing, and when you saw it"
  static let emptyTitle = "No species yet"
  static let emptyMessage = "Record what you saw on a dive and it will appear here."
  /// Said in place of the list when its first page failed, as the web's toast says it.
  static let failed = "Failed to load your species. Please try again."

  /// What a failed first page says: offline, that the list shows once it can be read.
  static func failure(_ error: APIError) -> String {
    error.isUnreachable ? OfflineText.lifeListNotShown : failed
  }
}

private struct MarineLifeListContent: View {
  @State var list: PagedList<SpeciesLifeListEntry>
  @Environment(Session.self) private var session

  var body: some View {
    ScrollView {
      LazyVStack(spacing: 12) {
        Text(MarineLifeListView.description)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .leading)
        switch list.phase {
        case .idle, .loading:
          EmptyOrErrorView(status: .loading)
            .padding(.top, 32)
        case .failed(let error):
          EmptyOrErrorView(status: .failed(message: MarineLifeListView.failure(error))) {
            Task { await list.refresh() }
          }
        case .loaded where list.items.isEmpty:
          EmptyOrErrorView(
            status: .empty(
              icon: .fish, title: MarineLifeListView.emptyTitle,
              message: MarineLifeListView.emptyMessage))
        case .loaded:
          if let lastUpdated = list.lastUpdated {
            LastUpdatedLine(date: lastUpdated)
          }
          ForEach(list.items) { entry in
            LifeListCard(entry: entry)
              .onAppear { Task { await list.loadMore(after: entry) } }
          }
          LoadMoreFooter(list: list)
        }
      }
      .padding()
    }
    .background(Color.pageBackground)
    .bubbleRefreshable { await list.refresh() }
    .navigationTitle(MarineLifeListView.title)
    .navigationBarTitleDisplayMode(.inline)
    .task { await list.show(following: session) }
  }
}

/// One species of the life list, its photo asked for as it scrolls into reach.
private struct LifeListCard: View {
  let entry: SpeciesLifeListEntry
  @Environment(Session.self) private var session
  @State private var photo: Data?

  var body: some View {
    CreditedSpeciesCard(
      speciesUUID: entry.uuid, content: .marineLife(entry, photo: photo)
    )
    .task(id: entry.photoSha256) {
      // A null version is the whole photo contract: no photo, and no request.
      guard let version = entry.photoSha256 else { return }
      photo = await SpeciesPhotos.photo(entry.uuid, version: version, session: session)
    }
  }
}

#Preview {
  NavigationStack {
    MarineLifeListView()
  }
  .environment(Session.stub(transport: StubTransport(routes: [:])))
}
