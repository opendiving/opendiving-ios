import OpenDivingKit
import SwiftUI

/// One trip's page, pushed from the dive page and the trips list: its hero, its dives under
/// the parts they were made on, and its *Trip Information* card.
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
        EmptyOrErrorView(status: .failed(message: error.message)) {
          Task { await model.load() }
        }
      case .loaded(let trip):
        ScrollView {
          VStack(spacing: 16) {
            HeroView(content: TripSummary.hero(trip, units: session.units))
            VStack(spacing: 16) {
              TripDives(trip: trip, list: model.dives, units: session.units)
              LoadMoreFooter(list: model.dives)
              TripInformationCard(trip: trip, contacts: model.contacts, people: session.people)
            }
            .padding([.horizontal, .bottom])
          }
        }
        .refreshable { await model.refresh() }
      }
    }
    .background(Color(.systemGroupedBackground))
    .navigationTitle(title)
    .navigationBarTitleDisplayMode(.inline)
    .task { await model.load() }
  }

  private var title: String {
    if case .loaded(let trip) = model.phase { trip.name } else { "Trip" }
  }
}

/// The trip's dives: a card for each part, headed by its place and dates, holding the dives
/// made on it, with the dives no part covers between them. A trip with no parts keeps one
/// card of every dive.
private struct TripDives: View {
  let trip: TripRead
  let list: PagedList<DiveListItem>
  let units: UnitSystem

  private static let title = "Dives in This Trip"
  private static let symbol = "water.waves"

  var body: some View {
    switch list.phase {
    case .idle, .loading:
      SectionCard(title: Self.title, systemImage: Self.symbol) {
        ProgressView()
          .frame(maxWidth: .infinity)
      }
    case .failed:
      SectionCard(title: Self.title, systemImage: Self.symbol) {
        Text("This trip's dives could not be loaded.")
          .font(.subheadline)
          .foregroundStyle(.secondary)
        Button("Try again") { Task { await list.load() } }
          .buttonStyle(.bordered)
      }
    case .loaded where trip.parts.isEmpty && list.items.isEmpty:
      EmptyOrErrorView(
        status: .empty(
          systemImage: Self.symbol, title: "No dives logged for this trip yet", message: nil))
    case .loaded where trip.parts.isEmpty:
      SectionCard(title: Self.title, systemImage: Self.symbol) {
        Text("Every dive logged on this trip")
          .font(.subheadline)
          .foregroundStyle(.secondary)
        DiveCardLinks(items: list.items, list: list, units: units)
      }
    case .loaded:
      let sections = TripDiveSection.sections(
        list.items, parts: TripSummary.spans(trip.parts), complete: !list.hasMore
      ) { $0.startTime.calendarDate }
      ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
        switch section {
        case .loose(let items):
          DiveCardLinks(items: items, list: list, units: units)
        case .part(let index, let items):
          let heading = TripSummary.partHeading(trip.parts[index])
          SectionCard(title: heading.title, systemImage: "mappin") {
            if let subtitle = heading.subtitle {
              Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            if items.isEmpty {
              Text("No dives logged for this part yet")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            } else {
              DiveCardLinks(items: items, list: list, units: units)
            }
          }
        }
      }
    }
  }
}

/// Each part's place, accommodation and dates, the people on the trip, its dive centres
/// and its notes — drawn only when the trip has any of them, as a card with nothing in it
/// but its heading would say nothing.
private struct TripInformationCard: View {
  let trip: TripRead
  let contacts: [UUID: ContactRead]
  let people: [UUID: PersonRead]

  var body: some View {
    let parts = TripSummary.partRows(trip, contacts: contacts)
    let people = PersonRowContent.rows(trip.people, people: people)
    let centres = TripSummary.diveCenters(trip, contacts: contacts)
    if !parts.isEmpty || !people.isEmpty || centres != nil || !trip.notes.isEmpty {
      SectionCard(title: "Trip Information", systemImage: "calendar") {
        VStack(alignment: .leading, spacing: 16) {
          if !parts.isEmpty {
            InfoRow(label: parts.count > 1 ? "Parts" : "Part") {
              VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(parts.enumerated()), id: \.offset) { _, part in
                  PartRowView(row: part)
                }
              }
            }
          }
          if !people.isEmpty {
            InfoRow(label: "People") {
              VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(people.enumerated()), id: \.offset) { _, person in
                  PersonRowView(content: person)
                }
              }
            }
          }
          if let centres {
            InfoRow(label: "Dive centers") {
              Text(centres)
            }
          }
          if !trip.notes.isEmpty {
            InfoRow(label: "Notes") {
              Text(trip.notes)
            }
          }
        }
      }
    }
  }
}

private struct PartRowView: View {
  let row: TripSummary.PartRow

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 8) {
      Image(systemName: "mappin")
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 2) {
        Text(row.place ?? "No place recorded")
          .foregroundStyle(row.place == nil ? Color.secondary : Color.primary)
        if let accommodation = row.accommodation {
          Label(accommodation, systemImage: "bed.double")
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
