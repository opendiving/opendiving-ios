import OpenDivingKit
import SwiftUI

/// One dive's page, pushed from any list of dive cards: the hero, then the main column's
/// cards and the sidebar's, stacked in the web's order. The pager in the navigation bar
/// steps to the dive before or after in place.
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
      guard model == nil else { return }
      let model = DiveDetailModel(session: session, diveUUID: diveUUID)
      self.model = model
      await model.load()
    }
  }
}

private struct DiveDetailScreen: View {
  let model: DiveDetailModel

  var body: some View {
    page
      .navigationTitle(model.content?.navigationTitle ?? "")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItemGroup(placement: .topBarTrailing) {
          pagerButton("Previous dive", systemImage: "chevron.left", model.neighbors?.previous)
          pagerButton("Next dive", systemImage: "chevron.right", model.neighbors?.next)
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
      EmptyOrErrorView(status: .failed(message: error.message)) {
        Task { await model.load() }
      }
    case .loaded(let dive):
      // The loaded dive's uuid, not the model's, which names the dive a step is heading to
      // while this one is still on screen.
      if let content = model.content {
        DiveDetailPage(content: content, diveUUID: dive.uuid) { uuid, version in
          await model.speciesPhoto(uuid, version: version)
        }
        .opacity(model.isStepping ? 0.5 : 1)
      }
    }
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
  let speciesPhoto: (UUID, String) async -> Data?

  var body: some View {
    ScrollView {
      VStack(spacing: 12) {
        HeroView(content: content.hero)
        VStack(spacing: 12) {
          mainColumn
          sidebar
        }
        .padding(.horizontal)
        .padding(.bottom)
      }
    }
    .background(Color(.systemGroupedBackground))
  }

  @ViewBuilder private var mainColumn: some View {
    if let profile = content.profile {
      DiveDetailProfileCard(diveUUID: diveUUID, profile: profile)
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
      SectionCard(title: "Notes", systemImage: "doc.text") {
        Text(notes)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
  }

  @ViewBuilder private var sidebar: some View {
    if let course = content.course {
      SectionCard(title: "Training", systemImage: "graduationcap") {
        InfoRow(label: "Course") {
          Label(course, systemImage: "graduationcap")
        }
      }
    }
    if let location = content.location {
      DiveDetailLocationCard(location: location)
    }
    if !content.people.isEmpty {
      SectionCard(title: "People", systemImage: "person.2") {
        VStack(alignment: .leading, spacing: 8) {
          ForEach(Array(content.people.enumerated()), id: \.offset) { _, person in
            PersonRowView(content: person)
          }
        }
      }
    }
    if !content.environment.isEmpty {
      SectionCard(title: "Environment", systemImage: "cloud.sun") {
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
