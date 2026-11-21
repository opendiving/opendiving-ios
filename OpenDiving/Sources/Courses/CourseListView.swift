import OpenDivingKit
import SwiftUI

/// More's *Courses*: what is waiting to sync, then the diver's courses in the API's order, a row
/// each on one card, each opening its page and holding *Edit* and *Delete* under a long press —
/// the pages the phone has shown first, from its copy.
struct CourseListView: View {
  @Environment(Session.self) private var session

  var body: some View {
    CourseListContent(model: CourseListModel(session: session))
  }
}

extension CourseListView {
  static let title = "Courses"
  static let emptyTitle = "No courses yet"
  static let emptyMessage = "Add the training you have done to group its dives and cards."
  static let emptyAction = "Add your first course"

  /// What a failed first page says: offline, that it shows once it can be read.
  static func failure(_ error: APIError) -> String {
    error.isUnreachable ? OfflineText.coursesNotShown : "Failed to load courses. Please try again."
  }
}

/// Where the list pushes a course's form.
private enum CourseFormRoute: Hashable {
  case create
  case edit(CourseRead)
}

private struct CourseListContent: View {
  @State var model: CourseListModel
  @Environment(OutboxModel.self) private var outbox
  @State private var route: CourseFormRoute?
  @State private var deleting: CourseRead?
  @State private var queueError: String?

  var body: some View {
    ScrollView {
      LazyVStack(spacing: 12) {
        // A queued create is not a row until it lands; what waits shows here however the
        // list stands.
        PendingSection()
        courses
      }
      .padding()
    }
    .background(Color.pageBackground)
    .bubbleRefreshable { await model.refresh() }
    .navigationTitle(CourseListView.title)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button("New course", systemImage: "plus") { route = .create }
      }
    }
    .navigationDestination(item: $route) { route in
      switch route {
      case .create: CourseFormView(mode: .create)
      case .edit(let course): CourseFormView(mode: .edit(course))
      }
    }
    .confirmationDialog(
      "Delete course",
      isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
      titleVisibility: .visible, presenting: deleting
    ) { course in
      Button("Delete", role: .destructive) {
        queueError = CourseDetailModel.delete(course.uuid, in: outbox)
      }
    } message: { _ in
      Text(RecordDeletionText.course)
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

  @ViewBuilder private var courses: some View {
    let list = model.courses
    switch list.phase {
    case .idle, .loading:
      EmptyOrErrorView(status: .loading)
        .padding(.top, 32)
    case .failed(let error):
      EmptyOrErrorView(status: .failed(message: CourseListView.failure(error))) {
        Task { await list.refresh() }
      }
    case .loaded where list.items.isEmpty:
      ContentUnavailableView {
        Label(CourseListView.emptyTitle, icon: .graduationCap)
      } description: {
        Text(CourseListView.emptyMessage)
      } actions: {
        Button(CourseListView.emptyAction, systemImage: "plus") { route = .create }
          .brandProminentButton()
      }
    case .loaded:
      if let lastUpdated = list.lastUpdated {
        LastUpdatedLine(date: lastUpdated)
      }
      // Lazy, so each row asks for the next page only as it scrolls into view.
      LazyVStack(spacing: 0) {
        ForEach(Array(list.items.enumerated()), id: \.element.id) { index, course in
          if index > 0 {
            Divider().padding(.leading, 12)
          }
          NavigationLink {
            CourseDetailView(courseUUID: course.uuid)
          } label: {
            CourseRow(content: .course(course))
          }
          .buttonStyle(.plain)
          .contentShape(.contextMenuPreview, .formSection)
          .contextMenu {
            Button("Edit", systemImage: "pencil") { route = .edit(course) }
            Button("Delete", systemImage: "trash", role: .destructive) { deleting = course }
          }
          .task { await list.loadMore(after: course) }
        }
      }
      .background(Color.cardFill, in: .formSection)
      .clipShape(.formSection)
      LoadMoreFooter(list: list)
    }
  }
}

/// A course's row on the list's card: its name over its dates and agency, its status at the
/// trailing edge.
private struct CourseRow: View {
  let content: PlainCardContent

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 12) {
      VStack(alignment: .leading, spacing: 2) {
        Text(content.title)
          .font(.headline)
        FactsLine(facts: content.facts, color: .primary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      ForEach(Array(content.badges.enumerated()), id: \.offset) { _, badge in
        BadgeView(badge)
      }
    }
    .padding(12)
    // A long press lifts the row alone, which takes a fill of its own.
    .background(Color.cardFill)
    .contentShape(.rect)
    .accessibilityElement(children: .combine)
  }
}

#Preview {
  NavigationStack {
    CourseListView()
  }
  .environment(DivePreviewData.session)
  .environment(OutboxModel(session: DivePreviewData.session))
  .environment(InboxModel(session: DivePreviewData.session))
}
