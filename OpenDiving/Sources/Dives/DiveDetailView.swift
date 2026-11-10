import OpenDivingKit
import SwiftUI

/// One dive's page, pushed from any list of dive cards: the hero, then the main column's
/// cards and the sidebar's, stacked in the web's order. The pager in the navigation bar
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
          hasPendingEdit: model.hasPendingEdit
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
  /// When the copy shown was fetched, while it is the phone's rather than this visit's.
  let lastUpdated: Date?
  let hasPendingEdit: Bool
  let speciesPhoto: (UUID, String) async -> Data?

  var body: some View {
    ScrollView {
      VStack(spacing: 12) {
        HeroView(content: content.hero)
        VStack(spacing: 12) {
          if let lastUpdated {
            LastUpdatedLine(date: lastUpdated)
          }
          if hasPendingEdit {
            PendingEditLine()
          }
          mainColumn
          sidebar
        }
        .padding(.horizontal)
        .padding(.bottom)
      }
    }
    .heroUnderTopBar()
    .background(Color.pageBackground)
  }

  @ViewBuilder private var mainColumn: some View {
    if let profile = content.profile {
      DiveDetailProfileCard(diveUUID: diveUUID, profile: profile, fromCopy: lastUpdated != nil)
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
    if let gear = content.gear {
      DiveDetailGearCard(gear: gear)
    }
    if !content.sightings.isEmpty {
      DiveDetailSpeciesCard(sightings: content.sightings, photo: speciesPhoto)
    }
    if let notes = content.notes {
      SectionCard(title: "Notes", icon: .fileText) {
        Text(notes)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
  }

  @ViewBuilder private var sidebar: some View {
    if let course = content.course {
      SectionCard(title: "Training", icon: .graduationCap) {
        InfoRow(label: "Course") {
          if let uuid = course.uuid {
            NavigationLink {
              CourseDetailView(courseUUID: uuid)
            } label: {
              Label(course.title, icon: .graduationCap)
            }
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
    if !content.environment.isEmpty {
      SectionCard(title: "Environment", icon: .cloudSun) {
        FiguresRow(figures: content.environment)
      }
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
