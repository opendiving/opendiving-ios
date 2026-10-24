import OpenDivingKit
import SwiftUI

/// The *Trips* tab: the diver's trips, the latest first, each opening its page.
struct TripsView: View {
  @Environment(Session.self) private var session

  var body: some View {
    NavigationStack {
      TripList(session: session)
        .navigationTitle("Trips")
    }
  }
}

extension TripsView {
  /// The tab's list, over the account's copy of the pages it has shown.
  static func list(_ session: Session) -> PagedList<TripRead> {
    PagedList(session: session, cache: .trips) { client, page, itemsPerPage in
      try await client.trips(page: page, itemsPerPage: itemsPerPage)
    }
  }
}

private struct TripList: View {
  @Environment(Session.self) private var session
  @State private var list: PagedList<TripRead>

  init(session: Session) {
    _list = State(initialValue: TripsView.list(session))
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
            systemImage: "suitcase", title: "No trips yet",
            message: "Trips you add on the web, or when logging a dive, appear here."))
      case .loaded:
        ScrollView {
          LazyVStack(spacing: 12) {
            if let lastUpdated = list.lastUpdated {
              LastUpdatedLine(date: lastUpdated)
            }
            ForEach(list.items) { trip in
              NavigationLink {
                TripDetailView(tripUUID: trip.uuid)
              } label: {
                RecordCardView(content: TripSummary.card(trip, units: session.units))
              }
              .buttonStyle(.plain)
              .onAppear { Task { await list.loadMore(after: trip) } }
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
  TripsView()
    .environment(Session.stub(transport: StubTransport(routes: [:])))
}
