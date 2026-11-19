import OpenDivingKit
import SwiftUI

/// One dive's page, pushed from any list of dive cards: the hero, then its cards in four tabs —
/// Info, Data, Gear and Marine life. The pager in the navigation bar
/// steps to the dive before or after in place. A dive the phone has opened before shows at
/// once from its copy, under when that was fetched, and an edit waiting to sync is marked.
struct DiveDetailView: View {
  let diveUUID: UUID

  @Environment(Session.self) private var session
  @State private var model: DiveDetailModel?

  var body: some View {
    Group {
      if let model {
        DiveDetailScreen(model: model)
      } else {
        EmptyOrErrorView(status: .loading)
      }
    }
    .task {
      if model == nil {
        let model = DiveDetailModel(session: session, diveUUID: diveUUID)
        self.model = model
        await model.load()
      }
      await model?.followRoute()
    }
  }
}

private struct DiveDetailScreen: View {
  let model: DiveDetailModel

  @Environment(\.dismiss) private var dismiss

  var body: some View {
    page
      .navigationTitle(model.content?.navigationTitle ?? "")
      .navigationBarTitleDisplayMode(.inline)
      // The title names the page in the back button's history; the head says it on screen.
      .toolbar(removing: .title)
      .toolbar {
        ToolbarItemGroup(placement: .topBarTrailing) {
          pagerButton("Previous dive", systemImage: "chevron.left", model.neighbors?.previous)
          pagerButton("Next dive", systemImage: "chevron.right", model.neighbors?.next)
        }
        if case .loaded(let dive) = model.phase {
          ToolbarIslandGap()
          ToolbarItemGroup(placement: .topBarTrailing) {
            if let content = model.content {
              RecordInfoButton(title: "Dive Information", sections: content.info)
            }
            NavigationLink {
              DiveFormView(mode: .edit(dive.uuid)) { dismiss() }
            } label: {
              Label("Edit dive", systemImage: "pencil")
            }
          }
        }
      }
  }

  @ViewBuilder private var page: some View {
    switch model.phase {
    case .loading:
      EmptyOrErrorView(status: .loading)
    case .failed(.http(status: 404, let message)):
      EmptyOrErrorView(status: .notFound(message: message ?? "This dive could not be found."))
    case .failed(let error):
      EmptyOrErrorView(status: .failed(message: Self.message(error))) {
        Task { await model.load() }
      }
    case .loaded(let dive):
      // The loaded dive's uuid, not the model's, which names the dive a step is heading to
      // while this one is still on screen.
      if let content = model.content {
        DiveDetailPage(
          content: content, diveUUID: dive.uuid, lastUpdated: model.lastUpdated,
          fromCopy: model.fetchedAt != nil, hasPendingEdit: model.hasPendingEdit,
          refresh: { await model.refresh() }
        ) { uuid, version in
          await model.speciesPhoto(uuid, version: version)
        }
        .opacity(model.isStepping ? 0.5 : 1)
      }
    }
  }

  /// A dive with no copy on the phone fails offline only once the request has waited for a
  /// route; it says why it needs one.
  private static func message(_ error: APIError) -> String {
    if error.isUnreachable { return OfflineText.diveNotShown }
    return error.message
  }

  /// An end of the log leaves its button in place and disabled, so the pair never shifts.
  private func pagerButton(_ direction: String, systemImage: String, _ neighbor: DiveNeighbor?)
    -> some View
  {
    Button {
      guard let neighbor else { return }
      Task { await model.show(neighbor.uuid) }
    } label: {
      Image(systemName: systemImage)
    }
    .disabled(neighbor == nil)
    .accessibilityLabel(
      neighbor.map {
        DiveDetailText.neighborLabel(direction, number: $0.diveNumber, start: $0.startTime)
      } ?? direction)
  }
}

private struct DiveDetailPage: View {
  let content: DiveDetailContent
  let diveUUID: UUID
  /// When the copy shown was fetched, while it is the phone's and no read is on its way.
  let lastUpdated: Date?
  /// What is shown is the phone's copy rather than this visit's.
  let fromCopy: Bool
  let hasPendingEdit: Bool
  let refresh: @Sendable () async -> Void
  let speciesPhoto: (UUID, String) async -> Data?

  /// Kept while the pager steps, so the next dive opens on the tab this one was read on.
  @State private var tab = DiveDetailContent.Tab.info
  @State private var scroll = ScrollPosition(edge: .top)
  @State private var tabsTop: CGFloat = 0
  @State private var reselect = TabsReselect.head
  @State private var tabsBottom: CGFloat = 0
  @State private var visibleHeight: CGFloat = 0

  /// The stack's gap under the tabs and the page's foot.
  private static let emptyGaps: CGFloat = 12 + 16
  /// What a message keeps where the head leaves less of the screen.
  private static let emptyMinHeight: CGFloat = 240

  var body: some View {
    ScrollView {
      VStack(spacing: 12) {
        HeroView(content: content.hero, detailsOnGlass: true)
        if lastUpdated != nil || hasPendingEdit {
          VStack(spacing: 12) {
            if let lastUpdated {
              LastUpdatedLine(date: lastUpdated)
            }
            if hasPendingEdit {
              PendingEditLine()
            }
          }
          .padding(.horizontal)
        }
        SectionTabs(
          selection: $tab,
          title: { tab in
            tab == .marineLife
              ? DiveSiteSummary.counted(tab.title, content.sightings.count) : tab.title
          },
          onReselect: { withAnimation { scroll.scroll(to: reselect) } }
        )
        .readsTabsTop($tabsTop)
        .onGeometryChange(for: CGFloat.self) {
          $0.frame(in: .pageContent).maxY
        } action: {
          tabsBottom = $0
        }
        VStack(spacing: 12) {
          if content.hasSections(in: tab) {
            switch tab {
            case .info: info
            case .data: data
            case .gear:
              if let gear = content.gear {
                DiveDetailGearCard(gear: gear)
              }
            case .marineLife:
              DiveDetailSpeciesCard(sightings: content.sightings, photo: speciesPhoto)
            }
          } else {
            // In the middle of what the screen shows under the tabs, at their place at rest.
            EmptyOrErrorView(status: Self.empty(tab))
              .frame(height: max(Self.emptyMinHeight, visibleHeight - tabsBottom - Self.emptyGaps))
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
    .heroUnderTopBar(refresh: refresh)
    .background(Color.pageBackground)
  }

  private static func empty(_ tab: DiveDetailContent.Tab) -> ContentStatus {
    switch tab {
    case .info: .empty(icon: .fileText, title: "Nothing else logged", message: nil)
    case .data: .empty(icon: .chartLine, title: "No profile or tanks logged", message: nil)
    case .gear: .empty(icon: .backpack, title: "No gear logged", message: nil)
    case .marineLife: .empty(icon: .fish, title: "No marine life logged", message: nil)
    }
  }

  @ViewBuilder private var info: some View {
    if !content.environment.isEmpty {
      SectionCard(title: "Environment", icon: .cloudSun) {
        FiguresRow(figures: content.environment)
      }
    }
    if let course = content.course {
      SectionCard(title: "Training", icon: .graduationCap) {
        InfoRow(label: "Course") {
          if let uuid = course.uuid {
            NavigationLink {
              CourseDetailView(courseUUID: uuid)
            } label: {
              Label(course.title, icon: .graduationCap)
            }
            .accentRow()
          } else {
            Label(course.title, icon: .graduationCap)
          }
        }
      }
    }
    if let location = content.location {
      DiveDetailLocationCard(location: location)
    }
    if !content.people.isEmpty {
      SectionCard(title: "People", icon: .users) {
        VStack(alignment: .leading, spacing: 8) {
          ForEach(Array(content.people.enumerated()), id: \.offset) { _, person in
            PersonRowView(content: person)
          }
        }
      }
    }
    if let notes = content.notes {
      SectionCard(title: "Notes", icon: .fileText) {
        Text(notes)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
  }

  @ViewBuilder private var data: some View {
    if let profile = content.profile {
      DiveDetailProfileCard(diveUUID: diveUUID, profile: profile, fromCopy: fromCopy)
    }
    if let tanks = content.tanks {
      DiveDetailTanksCard(tanks: tanks)
    }
    if let gas = content.gasConsumption {
      DiveDetailGasCard(gas: gas)
    }
    if let exposure = content.exposure {
      DiveDetailExposureCard(exposure: exposure)
    }
    if !content.recordings.isEmpty {
      DiveDetailRecordingsCard(recordings: content.recordings)
    }
  }
}

#Preview {
  NavigationStack {
    DiveDetailView(diveUUID: DivePreviewData.diveUUID)
  }
  .environment(DivePreviewData.session)
}
