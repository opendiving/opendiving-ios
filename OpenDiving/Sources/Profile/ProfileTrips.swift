import OpenDivingKit
import SwiftUI

/// The profile's *Trips*: the diver's trips, the latest first, each opening its page.
struct ProfileTrips: View {
  let list: PagedList<TripRead>
  let units: UnitSystem

  var body: some View {
    LazyVStack(spacing: 12) {
      switch list.phase {
      case .idle, .loading:
        EmptyOrErrorView(status: .loading)
          .padding(.top, 32)
      case .failed(let error):
        EmptyOrErrorView(status: .failed(message: error.message)) {
          Task { await list.load() }
        }
      case .loaded where list.items.isEmpty:
        EmptyOrErrorView(
          status: .empty(
            icon: .luggage, title: "No trips yet",
            message: "Add one with +, or when logging a dive."))
      case .loaded:
        if let lastUpdated = list.lastUpdated {
          LastUpdatedLine(date: lastUpdated)
        }
        ForEach(list.items) { trip in
          NavigationLink {
            TripDetailView(tripUUID: trip.uuid)
          } label: {
            RecordCardView(content: TripSummary.card(trip, units: units), icon: .tabLuggage)
          }
          .buttonStyle(.plain)
          .onAppear { Task { await list.loadMore(after: trip) } }
        }
        LoadMoreFooter(list: list)
      }
    }
  }
}

extension ProfileTrips {
  /// The trips' list, over the account's copy of the pages it has shown.
  static func list(_ session: Session) -> PagedList<TripRead> {
    PagedList(session: session, cache: .trips) { client, page, itemsPerPage in
      try await client.trips(page: page, itemsPerPage: itemsPerPage)
    }
  }
}

#Preview {
  let session = Session.stub(transport: StubTransport(routes: [:]))
  let list = ProfileTrips.list(session)
  NavigationStack {
    ScrollView {
      ProfileTrips(list: list, units: .metric)
        .padding()
    }
    .task { await list.load() }
  }
  .environment(session)
}
