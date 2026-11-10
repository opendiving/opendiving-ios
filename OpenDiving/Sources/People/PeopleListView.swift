import OpenDivingKit
import SwiftUI

/// More's *People*: what is waiting to sync, then the diver's people in the API's order, each
/// opening their page and holding *Edit* and *Delete* under a long press — the pages the phone
/// has shown first, from its copy.
struct PeopleListView: View {
  @Environment(Session.self) private var session

  var body: some View {
    PeopleListContent(model: PeopleListModel(session: session))
  }
}

extension PeopleListView {
  static let title = "People"
  static let description =
    "Your buddies, guides, instructors and the people who came along, kept once"
  static let listTitle = "People List"
  static let emptyTitle = "No people yet"
  static let emptyMessage =
    "Add the people you dive with once, and pick them from your dives, trips and courses."
  static let emptyAction = "Add your first person"

  /// What a failed first page says: offline, that it shows once it can be read.
  static func failure(_ error: APIError) -> String {
    error.isUnreachable ? OfflineText.peopleNotShown : "Failed to load people. Please try again."
  }
}

/// Where the list pushes a person's form.
private enum PersonFormRoute: Hashable {
  case create
  case edit(PersonRead)
}

private struct PeopleListContent: View {
  @State var model: PeopleListModel
  @Environment(OutboxModel.self) private var outbox
  @State private var route: PersonFormRoute?
  @State private var deleting: PersonRead?
  @State private var queueError: String?

  var body: some View {
    ScrollView {
      LazyVStack(spacing: 12) {
        Text(PeopleListView.description)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .leading)
        // A queued create is not a row until it lands; what waits shows here however the
        // list stands.
        PendingSection()
        people
      }
      .padding()
    }
    .background(Color.pageBackground)
    .bubbleRefreshable { await model.refresh() }
    .navigationTitle(PeopleListView.title)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button("New person", systemImage: "plus") { route = .create }
      }
    }
    .navigationDestination(item: $route) { route in
      switch route {
      case .create: PersonFormView(mode: .create)
      case .edit(let person): PersonFormView(mode: .edit(person))
      }
    }
    .confirmationDialog(
      "Delete person",
      isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
      titleVisibility: .visible, presenting: deleting
    ) { person in
      Button("Delete", role: .destructive) {
        queueError = PeopleListModel.delete(person.uuid, in: outbox)
      }
    } message: { _ in
      Text(RecordDeletionText.person)
    }
    .alert(
      "Not saved",
      isPresented: Binding(get: { queueError != nil }, set: { if !$0 { queueError = nil } })
    ) {
      Button("OK") {}
    } message: {
      Text(queueError ?? "")
    }
    .task { await model.show() }
  }

  @ViewBuilder private var people: some View {
    let list = model.people
    switch list.phase {
    case .idle, .loading:
      EmptyOrErrorView(status: .loading)
        .padding(.top, 32)
    case .failed(let error):
      EmptyOrErrorView(status: .failed(message: PeopleListView.failure(error))) {
        Task { await list.refresh() }
      }
    case .loaded where list.items.isEmpty:
      ContentUnavailableView {
        Label(PeopleListView.emptyTitle, icon: .users)
      } description: {
        Text(PeopleListView.emptyMessage)
      } actions: {
        Button(PeopleListView.emptyAction, systemImage: "plus") { route = .create }
          .brandProminentButton()
      }
    case .loaded:
      HStack(spacing: 8) {
        Image(.users)
          .foregroundStyle(.secondary)
          .accessibilityHidden(true)
        Text(PeopleListView.listTitle)
          .font(.headline)
          .accessibilityAddTraits(.isHeader)
        Spacer()
      }
      if let lastUpdated = list.lastUpdated {
        LastUpdatedLine(date: lastUpdated)
      }
      ForEach(list.items) { person in
        NavigationLink {
          PersonDetailView(personUUID: person.uuid)
        } label: {
          PlainCardView(content: .person(person))
        }
        .buttonStyle(.plain)
        .contextMenu {
          Button("Edit", systemImage: "pencil") { route = .edit(person) }
          Button("Delete", systemImage: "trash", role: .destructive) { deleting = person }
        }
        .task { await list.loadMore(after: person) }
      }
      LoadMoreFooter(list: list)
    }
  }
}

#Preview {
  NavigationStack {
    PeopleListView()
  }
  .environment(DivePreviewData.session)
  .environment(OutboxModel(session: DivePreviewData.session))
  .environment(InboxModel(session: DivePreviewData.session))
}
