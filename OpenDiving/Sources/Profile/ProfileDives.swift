import OpenDivingKit
import SwiftUI

/// The profile's *Dives*: the buttons that log a dive and import files, what is waiting to sync,
/// then the logbook, newest first as the server orders it, a page at a time — the pages the phone
/// has shown first, from its copy.
struct ProfileDives: View {
  let list: PagedList<DiveListItem>
  let units: UnitSystem

  var body: some View {
    LazyVStack(spacing: 12) {
      // However the list stands: a dive logged offline waits to sync like any other.
      AddDivesButtons()
      // What is waiting to sync shows however the list stands: offline with nothing kept, the
      // first page is a minute away.
      PendingSection()
      switch list.phase {
      case .idle, .loading:
        EmptyOrErrorView(status: .loading)
          .padding(.top, 32)
      case .failed(let error):
        EmptyOrErrorView(status: .failed(message: error.message)) {
          Task { await list.refresh() }
        }
      case .loaded where list.items.isEmpty:
        EmptyOrErrorView(
          status: .empty(
            icon: .dive, title: "No dives logged yet",
            message:
              "No dives yet. Log one or import your dive computer's files above, or download "
              + "them from the dive computer with the button on the left."
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

/// *Log a dive* and *Import files* side by side, the ways into the logbook the top bar's `+` also
/// offers.
private struct AddDivesButtons: View {
  var body: some View {
    HStack(spacing: 12) {
      NavigationLink {
        DiveFormView(mode: .create)
      } label: {
        Label("Log a dive", icon: .dive)
          .frame(maxWidth: .infinity)
      }
      .brandProminentButton()
      NavigationLink {
        ImportView()
      } label: {
        Label("Import files", icon: .upload)
          .frame(maxWidth: .infinity)
      }
      .brandBorderedButton()
    }
    .controlSize(.large)
  }
}

extension ProfileDives {
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
