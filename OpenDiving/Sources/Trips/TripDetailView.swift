import OpenDivingKit
import SwiftUI

/// One trip's page, pushed from the dive page and the trips list: its hero, then three tabs —
/// Info, its parts, people, dive centres and notes; Dives, under the parts they were made on;
/// and Aquatic life, the species seen on them.
struct TripDetailView: View {
  let tripUUID: UUID
  @Environment(Session.self) private var session

  var body: some View {
    TripDetailContent(model: TripDetailModel(session: session, tripUUID: tripUUID))
  }
}

private struct TripDetailContent: View {
  @Environment(Session.self) private var session
  @Environment(\.dismiss) private var dismiss
  @State private var model: TripDetailModel

  init(model: TripDetailModel) {
    _model = State(initialValue: model)
  }

  var body: some View {
    Group {
      switch model.phase {
      case .loading:
        EmptyOrErrorView(status: .loading)
      case .notFound:
        EmptyOrErrorView(status: .notFound(message: "Trip not found."))
      case .failed(let error):
        EmptyOrErrorView(
          status: .failed(
            message: error.isUnreachable ? OfflineText.tripNotShown : error.message)
        ) {
          Task { await model.load() }
        }
      case .loaded(let trip):
        TripDetailPage(trip: trip, model: model)
      }
    }
    .background(Color.pageBackground)
    .navigationTitle(title)
    .navigationBarTitleDisplayMode(.inline)
    // The title names the page in the back button's history; the head says it on screen.
    .toolbar(removing: .title)
    .toolbar {
      if case .loaded(let trip) = model.phase {
        ToolbarItemGroup(placement: .topBarTrailing) {
          NavigationLink {
            TripFormView(mode: .edit(trip)) { dismiss() }
          } label: {
            Label("Edit trip", systemImage: "pencil")
          }
        }
      }
    }
    .task {
      await model.load()
      await model.followRoute()
    }
  }

  private var title: String {
    if case .loaded(let trip) = model.phase { trip.name } else { "Trip" }
  }
}

private struct TripDetailPage: View {
  let trip: TripRead
  let model: TripDetailModel

  @Environment(Session.self) private var session
  @State private var tab = TripSection.info
  @State private var scroll = ScrollPosition(edge: .top)
  @State private var tabsTop: CGFloat = 0
  @State private var reselect = TabsReselect.head
  @State private var tabsBottom: CGFloat = 0
  @State private var visibleHeight: CGFloat = 0

  /// The stack's gap under the tabs and the page's foot.
  private static let emptyGaps: CGFloat = 16 + 16
  /// What a message keeps where the head leaves less of the screen.
  private static let emptyMinHeight: CGFloat = 240

  var body: some View {
    ScrollView {
      // Lazy, so the dives' last page asks for the next and each species card for its photo
      // as it scrolls into reach.
      LazyVStack(spacing: 16) {
        HeroView(content: TripSummary.hero(trip, units: session.units), detailsOnGlass: true)
        if model.lastUpdated != nil || model.hasPendingEdit {
          VStack(spacing: 16) {
            if let lastUpdated = model.lastUpdated {
              LastUpdatedLine(date: lastUpdated)
            }
            if model.hasPendingEdit {
              PendingEditLine()
            }
          }
          .padding(.horizontal)
        }
        SectionTabs(
          selection: $tab,
          title: { tab in
            switch tab {
            case .info: tab.title
            case .dives: DiveSiteSummary.counted(tab.title, trip.diveCount)
            case .aquaticLife: DiveSiteSummary.counted(tab.title, trip.speciesCount)
            }
          },
          onReselect: { withAnimation { scroll.scroll(to: reselect) } }
        )
        .readsTabsTop($tabsTop)
        .onGeometryChange(for: CGFloat.self) {
          $0.frame(in: .pageContent).maxY
        } action: {
          tabsBottom = $0
        }
        Group {
          switch tab {
          case .info:
            if TripInformation.isEmpty(trip, contacts: model.contacts, people: session.people) {
              empty(.empty(icon: .fileText, title: "Nothing else logged", message: nil))
            } else {
              TripInformation(trip: trip, contacts: model.contacts, people: session.people)
            }
          case .dives:
            if model.dives.phase == .loaded, trip.parts.isEmpty, model.dives.items.isEmpty {
              empty(
                .empty(icon: .dive, title: "No dives logged for this trip yet", message: nil))
            } else {
              TripDives(trip: trip, list: model.dives, units: session.units)
              PageEndTrigger(list: model.dives)
              LoadMoreFooter(list: model.dives)
            }
          case .aquaticLife:
            TripSpecies(model: model) { empty($0) }
          }
        }
        .padding(.horizontal)
      }
      .coordinateSpace(.pageContent)
      .padding(.bottom)
    }
    .scrollPosition($scroll)
    // The height less the insets, whose top is the content's at rest.
    .onScrollGeometryChange(for: CGFloat.self) {
      $0.containerSize.height
    } action: {
      visibleHeight = $1
    }
    .tabsReselect($reselect, tabsTop: tabsTop)
    .heroUnderTopBar { await model.refresh() }
  }

  /// In the middle of what the screen shows under the tabs, at their place at rest.
  private func empty(_ status: ContentStatus) -> some View {
    EmptyOrErrorView(status: status)
      .frame(height: max(Self.emptyMinHeight, visibleHeight - tabsBottom - Self.emptyGaps))
  }
}

/// The trip's dives as cards, each part's under its place and dates, with the dives no part
/// covers between them. The tab names them, so they stand in no card of their own.
private struct TripDives: View {
  let trip: TripRead
  let list: PagedList<DiveListItem>
  let units: UnitSystem

  var body: some View {
    switch list.phase {
    case .idle, .loading:
      BubbleSpinner()
        .frame(maxWidth: .infinity)
    case .failed(let error):
      VStack(alignment: .leading, spacing: 12) {
        Text(
          error.isUnreachable
            ? OfflineText.divesNotShown : "This trip's dives could not be loaded."
        )
        .font(.subheadline)
        .foregroundStyle(.secondary)
        Button("Try again") { Task { await list.load() } }
          .brandBorderedButton()
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    case .loaded where trip.parts.isEmpty:
      DiveCardLinks(items: list.items, units: units)
    case .loaded:
      let sections = TripDiveSection.sections(
        list.items, parts: TripSummary.spans(trip.parts), complete: !list.hasMore
      ) { $0.startTime.calendarDate }
      ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
        switch section {
        case .loose(let items):
          DiveCardLinks(items: items, units: units)
        case .part(let index, let items):
          let heading = TripSummary.partHeading(trip.parts[index])
          VStack(alignment: .leading, spacing: 8) {
            SectionTitle(title: heading.title, icon: .mapPin, subtitle: heading.subtitle)
            if items.isEmpty {
              Text("No dives logged for this part yet")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            } else {
              DiveCardLinks(items: items, units: units)
            }
          }
        }
      }
    }
  }
}

/// Each part's place, accommodation and dates, the people on the trip, its dive centres and its
/// notes, a card for each the trip has.
private struct TripInformation: View {
  let trip: TripRead
  let contacts: [UUID: ContactRead]
  let people: [UUID: PersonRead]

  static func isEmpty(
    _ trip: TripRead, contacts: [UUID: ContactRead], people: [UUID: PersonRead]
  ) -> Bool {
    trip.parts.isEmpty && PersonRowContent.rows(trip.people, people: people).isEmpty
      && TripSummary.diveCenters(trip, contacts: contacts) == nil && trip.notes.isEmpty
  }

  var body: some View {
    let parts = TripSummary.partRows(trip, contacts: contacts)
    let people = PersonRowContent.rows(trip.people, people: people)
    let centres = TripSummary.diveCenters(trip, contacts: contacts)
    if !parts.isEmpty {
      SectionCard(title: parts.count > 1 ? "Parts" : "Part", icon: .mapPin) {
        VStack(alignment: .leading, spacing: 12) {
          ForEach(Array(parts.enumerated()), id: \.offset) { _, part in
            PartRowView(row: part)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
    if !people.isEmpty {
      SectionCard(title: "People", icon: .users) {
        VStack(alignment: .leading, spacing: 8) {
          ForEach(Array(people.enumerated()), id: \.offset) { _, person in
            PersonRowView(content: person)
          }
        }
      }
    }
    if let centres {
      SectionCard(title: "Dive Centers", icon: .building2) {
        Text(centres)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
    if !trip.notes.isEmpty {
      SectionCard(title: "Notes", icon: .fileText) {
        Text(trip.notes)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
  }
}

/// The species seen on the trip's dives, read whole; `empty` draws a message in the space
/// under the tabs.
private struct TripSpecies<Empty: View>: View {
  let model: TripDetailModel
  @ViewBuilder let empty: (ContentStatus) -> Empty

  var body: some View {
    switch model.species {
    case .none:
      empty(.empty(icon: .fish, title: "No aquatic life logged on this trip yet", message: nil))
    case .loading:
      BubbleSpinner()
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    case .failed:
      empty(
        .empty(
          icon: .fish, title: "The species could not be loaded",
          message: "Pull down to try again."))
    case .loaded(let entries):
      ForEach(entries) { entry in
        CreditedSpeciesCard(
          speciesUUID: entry.uuid,
          content: SpeciesCardContent.lifeList(entry, photo: model.photos[entry.uuid])
        )
        .onAppear { Task { await model.photos.load(entry) } }
      }
    }
  }
}

private struct PartRowView: View {
  let row: TripSummary.PartRow

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 8) {
      Image(.mapPin)
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 2) {
        Text(row.place ?? "No place recorded")
          .foregroundStyle(row.place == nil ? Color.secondary : Color.primary)
        if let accommodation = row.accommodation {
          Label(accommodation, icon: .bedDouble)
            .font(.caption)
            .foregroundStyle(.secondary)
            .accessibilityLabel("Stayed at " + accommodation)
        }
        if let dates = row.dates {
          Text(dates)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
    }
  }
}

#Preview {
  NavigationStack {
    TripDetailView(tripUUID: UUID())
  }
  .environment(Session.stub(transport: StubTransport(routes: [:])))
}
