import OpenDivingKit
import SwiftUI

/// A record page's dives — a gear item's, a course's, a person's, a species' — a page at a time
/// as cards each opening the dive's page, under the card's title and the sentence under it. While
/// the list holds none it is the empty state alone, whose button opens the dive form on `logDive`.
struct RecordDivesSection: View {
  let list: PagedList<DiveListItem>
  let content: RecordDivesContent
  let units: UnitSystem
  /// What *Log a dive* opens the dive form on.
  let logDive: DiveFormMode

  var body: some View {
    switch list.phase {
    case .idle, .loading:
      card {
        BubbleSpinner()
          .frame(maxWidth: .infinity)
      }
    case .failed(let error):
      card {
        Text(error.isUnreachable ? OfflineText.divesNotShown : RecordDivesContent.failed)
          .font(.subheadline)
          .foregroundStyle(.secondary)
        Button("Try again") { Task { await list.load() } }
          .buttonStyle(.bordered)
      }
    case .loaded where list.items.isEmpty:
      ContentUnavailableView {
        Label(content.emptyTitle, icon: .dive)
      } description: {
        Text(content.emptyMessage)
      } actions: {
        NavigationLink {
          DiveFormView(mode: logDive)
        } label: {
          Label(content.logDiveLabel, systemImage: "plus")
        }
        .brandProminentButton()
      }
    case .loaded:
      card {
        DiveCardLinks(items: list.items, units: units)
        PageEndTrigger(list: list)
        LoadMoreFooter(list: list)
      }
    }
  }

  private func card(@ViewBuilder _ rows: () -> some View) -> some View {
    SectionCard(title: content.title, icon: .dive) {
      Text(content.description)
        .font(.subheadline)
        .foregroundStyle(.secondary)
      rows()
    }
  }
}

#Preview {
  let session = Session.stub(transport: StubTransport(routes: [:]))
  let list = PagedList<DiveListItem>(session: session) { client, page, itemsPerPage in
    try await client.dives(page: page, itemsPerPage: itemsPerPage)
  }
  NavigationStack {
    ScrollView {
      RecordDivesSection(list: list, content: .gearItem, units: .metric, logDive: .create)
        .padding()
    }
    .task { await list.load() }
  }
  .environment(session)
}
