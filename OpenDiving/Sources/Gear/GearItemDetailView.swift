import OpenDivingKit
import SwiftUI

/// A gear item's page, by its uuid: its hero, then two tabs — Service, its notes over its
/// schedules and history; and Dives, those it was used on. It is edited, archived and unarchived
/// from its top bar, and deleted from its edit form.
struct GearItemDetailView: View {
  let gearItemUUID: UUID
  @Environment(Session.self) private var session

  var body: some View {
    GearItemDetailContent(
      model: GearItemDetailModel(session: session, gearItemUUID: gearItemUUID))
  }
}

extension GearItemDetailView {
  static let notFound = "Gear not found."

  /// What a page that could not be read says: offline, that it shows once it can be.
  static func failure(_ error: APIError) -> String {
    error.isUnreachable ? OfflineText.gearItemNotShown : error.message
  }
}

private struct GearItemDetailContent: View {
  @Environment(Session.self) private var session
  @Environment(OutboxModel.self) private var outbox
  @Environment(\.dismiss) private var dismiss
  @State private var model: GearItemDetailModel

  @State private var confirmsArchive = false
  @State private var queueError: String?
  @State private var section = GearItemSection.service
  @State private var scroll = ScrollPosition(edge: .top)
  @State private var tabsTop: CGFloat = 0
  @State private var reselect = TabsReselect.head
  @State private var tabsStuck = false
  @State private var serviceRoute: GearServiceRoute?

  init(model: GearItemDetailModel) {
    _model = State(initialValue: model)
  }

  var body: some View {
    Group {
      switch model.page.phase {
      case .loading:
        EmptyOrErrorView(status: .loading)
      case .notFound:
        EmptyOrErrorView(status: .notFound(message: GearItemDetailView.notFound))
      case .failed(let error):
        EmptyOrErrorView(status: .failed(message: GearItemDetailView.failure(error))) {
          Task { await model.load() }
        }
      case .loaded(let item):
        ScrollView {
          LazyVStack(spacing: 16) {
            HeroView(
              content: GearItemPageContent.hero(
                item, units: session.units, today: CalendarDate.today()),
              backdrop: .plain)
            if model.page.lastUpdated != nil || model.page.hasPendingEdit {
              VStack(spacing: 16) {
                if let lastUpdated = model.page.lastUpdated {
                  LastUpdatedLine(date: lastUpdated)
                }
                if model.page.hasPendingEdit {
                  PendingEditLine()
                }
              }
              .padding(.horizontal)
            }
            ScrollingSectionTabs(
              selection: $section, isStuck: $tabsStuck, top: $tabsTop, title: tabTitle,
              onReselect: scrollOnReselect)
            Group {
              switch section {
              case .service:
                if let notes = GearItemPageContent.notes(item) {
                  SectionCard(title: "Notes", icon: .fileText) {
                    Text(notes)
                      .foregroundStyle(.secondary)
                  }
                }
                LinksCard(links: ShownLink.list(item.links))
                GearServiceCard(gearItem: item, service: model.service, route: $serviceRoute)
              case .dives:
                RecordDivesSection(
                  list: model.dives, content: .gearItem, units: session.units, logDive: .create,
                  isCarded: false)
              }
            }
            .padding(.horizontal)
            .hiddenUnderTopBar()
          }
          .coordinateSpace(.pageContent)
          .padding(.bottom)
        }
        .scrollPosition($scroll)
        .tabsReselect($reselect, tabsTop: tabsTop)
        .overlay(alignment: .top) {
          StuckSectionTabs(
            selection: $section, isStuck: tabsStuck, title: tabTitle, onReselect: scrollOnReselect)
        }
        .heroUnderTopBar { await model.refresh() }
        .toolbar { actions(item) }
        .navigationDestination(item: $serviceRoute) {
          GearServiceCard.form($0, gearItem: item.uuid)
        }
        .confirmationDialog(
          "Archive gear", isPresented: $confirmsArchive, titleVisibility: .visible
        ) {
          Button("Archive") { queue(GearItemDetailModel.archiveToggle(item)) }
        } message: {
          Text(RecordDeletionText.archiveGearItem(item))
        }
      }
    }
    .background(Color.pageBackground)
    .navigationTitle(title)
    .navigationBarTitleDisplayMode(.inline)
    // The title names the page in the back button's history; the head says it on screen.
    .toolbar(removing: .title)
    .alert(
      "Not saved",
      isPresented: Binding(get: { queueError != nil }, set: { if !$0 { queueError = nil } })
    ) {
      Button("OK") {}
    } message: {
      Text(queueError ?? "")
    }
    .task {
      await model.load()
      await model.followRoute()
    }
  }

  @ToolbarContentBuilder private func actions(_ item: GearItemRead) -> some ToolbarContent {
    ToolbarItemGroup(placement: .topBarTrailing) {
      NavigationLink {
        GearItemFormView(mode: .edit(item)) { dismiss() }
      } label: {
        Label("Edit", systemImage: "pencil")
      }
      Menu {
        if item.isArchived {
          // Bringing it back is undone as easily, so it asks nothing.
          Button("Unarchive", systemImage: "archivebox") {
            queue(GearItemDetailModel.archiveToggle(item))
          }
        } else {
          Button("Archive", systemImage: "archivebox") { confirmsArchive = true }
        }
      } label: {
        Label(
          "Actions for " + DiveDetailText.gearItemLabel(name: item.name, brand: item.brand),
          systemImage: "ellipsis")
      }
    }
  }

  /// Queues the write; where it was not, the reason is on screen.
  private func queue(_ operation: OutboxOperation) {
    queueError = GearItemDetailModel.queue(operation, in: outbox)
  }

  private func tabTitle(_ section: GearItemSection) -> String {
    switch section {
    case .service: section.title
    case .dives: DiveSiteSummary.counted(section.title, model.dives.count ?? 0)
    }
  }

  private func scrollOnReselect() {
    withAnimation { scroll.scroll(to: reselect) }
  }

  private var title: String {
    if case .loaded(let item) = model.page.phase { item.name } else { "Gear" }
  }
}

#Preview {
  NavigationStack {
    GearItemDetailView(gearItemUUID: UUID())
  }
  .environment(DivePreviewData.session)
  .environment(OutboxModel(session: DivePreviewData.session))
}
