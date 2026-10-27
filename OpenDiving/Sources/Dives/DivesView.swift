import OpenDivingKit
import SwiftUI

/// The *Dives* tab: the logbook, newest first as the server orders it, a page at a time — the
/// pages the phone has shown first, from its copy — what is waiting to sync above it, and the
/// `+` that logs a dive or imports files.
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
            Button(
              DiveComputerText.connectMenuItem, systemImage: "antenna.radiowaves.left.and.right"
            ) {
              route = .diveComputer
            }
          }
        }
      }
      .navigationDestination(item: $route) { route in
        switch route {
        case .logDive: DiveFormView(mode: .create)
        case .importFiles: ImportView()
        case .diveComputer: DiveComputerView()
        }
      }
    }
    .task {
      guard list == nil else { return }
      let list = Self.list(session)
      self.list = list
      await list.load()
    }
  }
}

extension DivesView {
  /// The logbook's list, over the account's copy of the pages it has shown.
  static func list(_ session: Session) -> PagedList<DiveListItem> {
    PagedList(session: session, cache: .dives) { client, page, itemsPerPage in
      try await client.dives(page: page, itemsPerPage: itemsPerPage)
    }
  }
}

/// Where the `+` leads, mirroring the web's Dives header.
private enum DivesRoute: Hashable {
  case logDive, importFiles, diveComputer
}

private struct DivesList: View {
  let list: PagedList<DiveListItem>
  let units: UnitSystem

  var body: some View {
    switch list.phase {
    // What is waiting to sync shows however the list stands: offline with nothing kept, the
    // first page is a minute away.
    case .idle, .loading:
      VStack(spacing: 0) {
        pending
        EmptyOrErrorView(status: .loading)
      }
    case .failed(let error):
      VStack(spacing: 0) {
        pending
        EmptyOrErrorView(status: .failed(message: error.message)) {
          Task { await list.refresh() }
        }
      }
    case .loaded where list.items.isEmpty:
      VStack(spacing: 0) {
        pending
        EmptyOrErrorView(
          status: .empty(
            systemImage: "water.waves", title: "No dives logged yet",
            message:
              "No dives yet. Log one, import your dive computer's files, or connect your dive "
              + "computer, with +."
          )
        )
      }
      .refreshable { await list.refresh() }
    case .loaded:
      ScrollView {
        LazyVStack(spacing: 12) {
          PendingSection()
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
        .padding()
      }
      .background(Color(.systemGroupedBackground))
      .refreshable { await list.refresh() }
    }
  }

  private var pending: some View {
    PendingSection()
      .padding([.horizontal, .top])
  }
}

#Preview {
  DivesView()
    .environment(DivePreviewData.session)
    .environment(InboxModel(session: DivePreviewData.session))
    .environment(OutboxModel(session: DivePreviewData.session))
}
