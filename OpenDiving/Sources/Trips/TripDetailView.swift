import OpenDivingKit
import SwiftUI

/// One trip's page, pushed from the dive page and the trips list: its hero, then three tabs —
/// Info, its parts, people, dive centres and notes; Dives, under the parts they were made on
/// where it has more than one; and Aquatic life, the species seen on them.
struct TripDetailView: View {
  let tripUUID: UUID
  @Environment(Session.self) private var session

  var body: some View {
    TripDetailContent(model: TripDetailModel(session: session, tripUUID: tripUUID))
  }
}

private struct TripDetailContent: View {
  @Environment(Session.self) private var session
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
  @Environment(\.dismiss) private var dismiss
  @State private var tab = TripSection.info
  @State private var scroll = ScrollPosition(edge: .top)
  @State private var tabsStuck = false
  @State private var tabsTop: CGFloat = 0
  @State private var reselect = TabsReselect.head
  @State private var tabsBottom: CGFloat = 0
  @State private var visibleHeight: CGFloat = 0
  /// Where each part's heading among the dives sits down the page, by the part's index.
  @State private var partTops: [Int: CGFloat] = [:]
  /// The content offset that brings each landing to the bar.
  @State private var landings: [Landing: CGFloat] = [:]

  /// The stack's gap between its rows.
  private static let gap: CGFloat = 16
  /// The stack's gap under the tabs and the page's foot.
  private static let emptyGaps: CGFloat = gap + 16
  /// What a message keeps where the head leaves less of the screen.
  private static let emptyMinHeight: CGFloat = 240

  var body: some View {
    ScrollView {
      // Lazy, so the dives' last page asks for the next and each species card for its photo
      // as it scrolls into reach.
      LazyVStack(spacing: Self.gap) {
        HeroView(content: TripSummary.hero(trip), detailsOnGlass: true)
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
        ScrollingSectionTabs(
          selection: $tab, isStuck: $tabsStuck, top: $tabsTop, title: tabTitle,
          onReselect: scrollOnReselect
        )
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
            if model.dives.phase == .loaded, trip.parts.count < 2, model.dives.items.isEmpty {
              empty(
                .empty(icon: .dive, title: "No dives logged for this trip yet", message: nil))
            } else {
              TripDives(
                trip: trip, sections: diveSections, list: model.dives, units: session.units,
                partTops: $partTops)
              PageEndTrigger(list: model.dives)
              LoadMoreFooter(list: model.dives)
            }
          case .aquaticLife:
            TripSpecies(model: model) { empty($0) }
          }
        }
        .padding(.horizontal)
        .hiddenUnderTopBar()
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
    .offsetsToBar($landings, tops: landingTops)
    .readsTabsStuck($tabsStuck, tabsTop: tabsTop)
    // A section chosen under the held tabs starts just under them, rather than wherever the
    // last one was scrolled to, which may be past the end of a shorter one.
    .onChange(of: tab) {
      if tabsStuck, let offset = landings[.tabs] {
        scroll.scrollTo(y: offset)
      }
    }
    .overlay(alignment: .top) {
      StuckSectionTabs(
        selection: $tab, isStuck: tabsStuck, title: tabTitle, onReselect: scrollOnReselect)
    }
    .heroUnderTopBar { await model.refresh() }
    .toolbar {
      ToolbarItemGroup(placement: .topBarTrailing) {
        if tab == .dives, diveSections != nil {
          partsMenu
        }
        NavigationLink {
          TripFormView(mode: .edit(trip)) { dismiss() }
        } label: {
          Label("Edit trip", systemImage: "pencil")
        }
      }
    }
  }

  private func tabTitle(_ tab: TripSection) -> String {
    switch tab {
    case .info: tab.title
    case .dives: DiveSiteSummary.counted(tab.title, trip.diveCount)
    case .aquaticLife: DiveSiteSummary.counted(tab.title, trip.speciesCount)
    }
  }

  private func scrollOnReselect() {
    withAnimation { scroll.scroll(to: reselect) }
  }

  /// The dives under the parts they were made on, for a trip of more than one; nil until the
  /// dives are read.
  private var diveSections: [TripDiveSection<DiveListItem>]? {
    guard trip.parts.count > 1, model.dives.phase == .loaded else { return nil }
    let list = model.dives
    return TripDiveSection.sections(
      list.items, parts: TripSummary.spans(trip.parts), complete: !list.hasMore
    ) { $0.startTime.calendarDate }
  }

  /// The parts the dives show, in their order down the page, each scrolling its heading to just
  /// under the held tabs.
  private var partsMenu: some View {
    Menu("Parts", systemImage: "list.bullet") {
      ForEach(diveSections?.compactMap(\.partIndex) ?? [], id: \.self) { index in
        let heading = TripSummary.partHeading(trip.parts[index])
        Button {
          if let offset = landings[.part(index)] {
            withAnimation { scroll.scrollTo(y: offset) }
          }
        } label: {
          Text(heading.title)
          if let subtitle = heading.subtitle {
            Text(subtitle)
          }
        }
      }
    }
  }

  /// What lands at the bar's foot for each landing: the tabs' top, and each part's heading the
  /// tabs' height and the gap under them further down, so it shows just under the held tabs.
  private var landingTops: [Landing: CGFloat] {
    var tops: [Landing: CGFloat] = [.tabs: tabsTop]
    let under = tabsBottom - tabsTop + Self.gap
    for (index, top) in partTops {
      tops[.part(index)] = top - under
    }
    return tops
  }

  /// In the middle of what the screen shows under the tabs, at their place at rest.
  private func empty(_ status: ContentStatus) -> some View {
    EmptyOrErrorView(status: status)
      .frame(height: max(Self.emptyMinHeight, visibleHeight - tabsBottom - Self.emptyGaps))
  }
}

/// Where the trip's page scrolls something to the top bar's foot: its tabs, or a part's
/// heading among the dives.
private enum Landing: Hashable {
  case tabs
  case part(Int)
}

extension View {
  /// Keeps `offsets` at the content offset that brings each of `tops`, a place down the
  /// ``NamedCoordinateSpace/pageContent``, to the top bar's foot, or as near as this scroll view
  /// goes.
  fileprivate func offsetsToBar(
    _ offsets: Binding<[Landing: CGFloat]>, tops: [Landing: CGFloat]
  ) -> some View {
    modifier(OffsetsToBarReading(offsets: offsets, tops: tops))
  }
}

/// Read in the scroll view, under ``View/heroUnderTopBar(refresh:)``, which sets the inset.
extension View {
  /// Whether the tabs are at the bar, by the page's offset rather than by the tabs alone: a
  /// part picked from the menu jumps the page past them, and the lazy stack lets them go before
  /// they can say they reached it.
  fileprivate func readsTabsStuck(_ isStuck: Binding<Bool>, tabsTop: CGFloat) -> some View {
    modifier(TabsStuckReading(isStuck: isStuck, tabsTop: tabsTop))
  }
}

private struct TabsStuckReading: ViewModifier {
  @Binding var isStuck: Bool
  let tabsTop: CGFloat
  @Environment(\.heroTopInset) private var topInset

  func body(content: Content) -> some View {
    content.onScrollGeometryChange(for: Bool.self) {
      [tabsTop, topInset] geometry in
      // Nothing before the tabs are measured: a top of nought would read as at the bar.
      tabsTop > 0 && geometry.contentOffset.y >= tabsTop - topInset
    } action: {
      isStuck = $1
    }
  }
}

private struct OffsetsToBarReading: ViewModifier {
  @Binding var offsets: [Landing: CGFloat]
  let tops: [Landing: CGFloat]
  @Environment(\.heroTopInset) private var topInset

  func body(content: Content) -> some View {
    content.onScrollGeometryChange(for: [Landing: CGFloat].self) {
      [tops, topInset] geometry in
      let top = -geometry.contentInsets.top
      // The container is the scroll view's height less its insets.
      let bottom = max(top, top + geometry.contentSize.height - geometry.containerSize.height)
      return tops.mapValues { min(max($0 - topInset, top), bottom) }
    } action: {
      offsets = $1
    }
  }
}

/// The trip's dives as cards, each part's under its place and dates, with the dives no part
/// covers between them. The tab names them, so they stand in no card of their own, and a
/// trip of one part is that part, whose place and dates the hero already gives, so its dives
/// stand under no heading.
private struct TripDives: View {
  let trip: TripRead
  /// The dives under their parts, for a trip of more than one.
  let sections: [TripDiveSection<DiveListItem>]?
  let list: PagedList<DiveListItem>
  let units: UnitSystem
  @Binding var partTops: [Int: CGFloat]

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
    case .loaded:
      if let sections {
        // Laid out together, as each part's cards already are, so the parts menu knows where
        // every part's heading sits before the page scrolls to it.
        VStack(spacing: 16) {
          ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
            switch section {
            case .loose(let items):
              DiveCardLinks(items: items, units: units)
            case .part(let index, let items):
              part(index, items: items)
            }
          }
        }
      } else {
        DiveCardLinks(items: list.items, units: units)
      }
    }
  }

  private func part(_ index: Int, items: [DiveListItem]) -> some View {
    let heading = TripSummary.partHeading(trip.parts[index])
    return VStack(alignment: .leading, spacing: 8) {
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
    .onGeometryChange(for: CGFloat.self) {
      $0.frame(in: .pageContent).minY
    } action: {
      partTops[index] = $0
    }
  }
}

/// Each part's place, dates and accommodation, the people on the trip, its dive centres and its
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
        ForEach(Array(parts.enumerated()), id: \.offset) { index, part in
          if index > 0 { Divider() }
          PartRowView(row: part)
        }
      }
    }
    if !people.isEmpty {
      SectionCard(title: "People", icon: .users) {
        ForEach(Array(people.enumerated()), id: \.offset) { index, person in
          if index > 0 { Divider() }
          PersonRowView(content: person)
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
          content: SpeciesCardContent.aquaticLife(entry, photo: model.photos[entry.uuid])
        )
        .onAppear { Task { await model.photos.load(entry) } }
      }
    }
  }
}

/// A part's place, then its dates and where the diver stayed, each led by its icon, in a
/// person's row's size and colours.
private struct PartRowView: View {
  let row: TripSummary.PartRow

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(row.place ?? "No place recorded")
        .fontWeight(row.place == nil ? .regular : .medium)
        .foregroundStyle(row.place == nil ? Color.secondary : Color.primary)
      if let dates = row.dates {
        line(icon: .calendar) {
          Text(dates).foregroundStyle(.secondary)
        }
      }
      if let accommodation = row.accommodation {
        line(icon: .bedDouble) {
          Text(accommodation).foregroundStyle(.secondary)
        }
        .accessibilityLabel("Stayed at " + accommodation)
      }
    }
    .font(.subheadline)
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .combine)
  }

  private func line(icon: Icon, @ViewBuilder text: () -> some View) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 8) {
      Image(icon)
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)
      text()
    }
  }
}

#Preview {
  NavigationStack {
    TripDetailView(tripUUID: UUID())
  }
  .environment(Session.stub(transport: StubTransport(routes: [:])))
}
