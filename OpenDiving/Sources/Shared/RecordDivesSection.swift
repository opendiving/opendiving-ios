import OpenDivingKit
import SwiftUI

/// A record page's dives — a gear item's, a course's, a person's, a species' — a page at a time
/// as cards each opening the dive's page, under the card's title and the sentence under it — or,
/// not `isCarded`, the dive cards alone, where a tab already names them. While the list holds none
/// it is the empty state alone, under `emptyAction`: *Log a dive* unless the page gives another.
struct RecordDivesSection<EmptyAction: View>: View {
  let list: PagedList<DiveListItem>
  let content: RecordDivesContent
  let units: UnitSystem
  var isCarded = true
  @ViewBuilder let emptyAction: () -> EmptyAction

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
          .brandBorderedButton()
      }
    case .loaded where list.items.isEmpty:
      ContentUnavailableView {
        Label(content.emptyTitle, icon: .dive)
      } description: {
        Text(content.emptyMessage)
      } actions: {
        emptyAction()
      }
    case .loaded:
      card {
        DiveCardLinks(items: list.items, units: units)
        PageEndTrigger(list: list)
        LoadMoreFooter(list: list)
      }
    }
  }

  @ViewBuilder private func card(@ViewBuilder _ rows: () -> some View) -> some View {
    if isCarded {
      SectionCard(title: content.title, icon: .dive) {
        Text(content.description)
          .font(.subheadline)
          .foregroundStyle(.secondary)
        rows()
      }
    } else {
      VStack(alignment: .leading, spacing: 12) {
        rows()
      }
    }
  }
}

extension RecordDivesSection where EmptyAction == RecordDivesLogDive {
  /// The section whose empty state logs a dive, the form opening on `logDive`.
  init(
    list: PagedList<DiveListItem>, content: RecordDivesContent, units: UnitSystem,
    logDive: DiveFormMode, isCarded: Bool = true
  ) {
    self.init(list: list, content: content, units: units, isCarded: isCarded) {
      RecordDivesLogDive(label: content.logDiveLabel, mode: logDive)
    }
  }
}

/// The empty state's *Log a dive*, opening the dive form on `mode`.
struct RecordDivesLogDive: View {
  let label: String
  let mode: DiveFormMode

  var body: some View {
    NavigationLink {
      DiveFormView(mode: mode)
    } label: {
      Label(label, systemImage: "plus")
    }
    .brandProminentButton()
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
