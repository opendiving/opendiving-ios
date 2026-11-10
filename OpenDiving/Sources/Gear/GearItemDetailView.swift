import OpenDivingKit
import SwiftUI

/// A gear item's page, by its uuid: its hero, its service, the dives it was used on and its
/// notes. It is edited, archived, unarchived and deleted from its top bar.
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
  @State private var confirmsDelete = false
  @State private var queueError: String?

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
                item, units: session.units, today: CalendarDate.today()))
            Group {
              if let lastUpdated = model.page.lastUpdated {
                LastUpdatedLine(date: lastUpdated)
              }
              if model.page.hasPendingEdit {
                PendingEditLine()
              }
              GearServiceCard(gearItem: item)
              RecordDivesSection(
                list: model.dives, content: .gearItem, units: session.units, logDive: .create)
              if let notes = GearItemPageContent.notes(item) {
                SectionCard(title: "Notes", icon: .fileText) {
                  Text(notes)
                    .foregroundStyle(.secondary)
                }
              }
            }
            .padding(.horizontal)
          }
          .padding(.bottom)
        }
        .heroUnderTopBar { await model.refresh() }
        .toolbar { actions(item) }
        .confirmationDialog(
          "Archive gear", isPresented: $confirmsArchive, titleVisibility: .visible
        ) {
          Button("Archive") { queue(GearItemDetailModel.archiveToggle(item)) }
        } message: {
          Text(RecordDeletionText.archiveGearItem(item))
        }
        .confirmationDialog("Delete gear", isPresented: $confirmsDelete, titleVisibility: .visible)
        {
          Button("Delete", role: .destructive) {
            if queue(.deleteGearItem(.server(item.uuid))) { dismiss() }
          }
          if GearItemDetailModel.offersArchiveInstead(item) {
            // Straight to the archive: the sentence being read already says what it does.
            Button("Archive instead") { queue(GearItemDetailModel.archiveToggle(item)) }
          }
        } message: {
          Text(RecordDeletionText.gearItem)
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
        GearItemFormView(mode: .edit(item))
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
        Button("Delete", systemImage: "trash", role: .destructive) { confirmsDelete = true }
      } label: {
        Label(
          "Actions for " + DiveDetailText.gearItemLabel(name: item.name, brand: item.brand),
          systemImage: "ellipsis")
      }
    }
  }

  /// Whether the write was queued; where it was not, the reason is on screen.
  @discardableResult private func queue(_ operation: OutboxOperation) -> Bool {
    queueError = GearItemDetailModel.queue(operation, in: outbox)
    return queueError == nil
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
