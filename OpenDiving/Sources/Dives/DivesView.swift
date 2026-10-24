import OpenDivingKit
import SwiftUI

/// The *Dives* tab: the logbook, newest first as the server orders it, a page at a time, and
/// the `+` that logs a dive or imports files.
struct DivesView: View {
  @Environment(Session.self) private var session
  @State private var list: PagedList<DiveListItem>?
  @State private var route: DivesRoute?

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
      .toolbar {
        ToolbarItem(placement: .primaryAction) {
          Menu("Add", systemImage: "plus") {
            Button("Log a dive", systemImage: "square.and.pencil") { route = .logDive }
            Button("Import files", systemImage: "square.and.arrow.down") { route = .importFiles }
          }
        }
      }
      .navigationDestination(item: $route) { route in
        switch route {
        case .logDive: DiveFormView(mode: .create)
        case .importFiles: ImportView()
        }
      }
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

/// Where the `+` leads, mirroring the web's Dives header.
private enum DivesRoute: Hashable {
  case logDive, importFiles
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
      VStack(spacing: 0) {
        PendingSection()
        EmptyOrErrorView(
          status: .empty(
            systemImage: "water.waves", title: "No dives logged yet",
            message: "No dives yet. Log one, or import your dive computer's files, with +.")
        )
      }
      .refreshable { await list.refresh() }
    case .loaded:
      ScrollView {
        LazyVStack(spacing: 12) {
          PendingSection()
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
    .environment(InboxModel(session: DivePreviewData.session))
}
