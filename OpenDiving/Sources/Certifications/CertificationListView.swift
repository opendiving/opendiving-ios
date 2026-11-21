import OpenDivingKit
import SwiftUI

/// More's *Certifications*: the diver's c-cards, newest certified first, each over its front
/// image at the card's shape and opening its pane — the pages the phone has shown first, from its
/// copy. A card being created waits in the pending summary above them.
struct CertificationListView: View {
  @Environment(Session.self) private var session

  var body: some View {
    CertificationListContent(list: .certifications(session))
  }
}

extension CertificationListView {
  static let title = "Certifications"
  static let emptyTitle = "No certifications yet"
  static let emptyMessage = "Add your c-cards so you always have them on hand at the dive shop."
  static let emptyAction = "Add your first certification"
  static let newLabel = "New certification"
  /// Said in place of the list when its first page failed, as the web's toast says it.
  static let failed = "Failed to load certifications. Please try again."

  /// What a failed first page says: offline, that the list shows once it can be read.
  static func failure(_ error: APIError) -> String {
    error.isUnreachable ? OfflineText.certificationsNotShown : failed
  }
}

private struct CertificationListContent: View {
  @State var list: PagedList<CertificationRead>
  @Environment(Session.self) private var session
  @State private var creating = false
  @State private var opened: CertificationRead?

  var body: some View {
    ScrollView {
      LazyVStack(spacing: 12) {
        PendingSection()
        switch list.phase {
        case .idle, .loading:
          EmptyOrErrorView(status: .loading)
            .padding(.top, 32)
        case .failed(let error):
          EmptyOrErrorView(status: .failed(message: CertificationListView.failure(error))) {
            Task { await list.refresh() }
          }
        case .loaded where list.items.isEmpty:
          EmptyOrErrorView(
            status: .empty(
              icon: .badgeCheck, title: CertificationListView.emptyTitle,
              message: CertificationListView.emptyMessage))
          Button(CertificationListView.emptyAction, systemImage: "plus") { creating = true }
            .brandProminentButton()
        case .loaded:
          if let lastUpdated = list.lastUpdated {
            LastUpdatedLine(date: lastUpdated)
          }
          let today = CalendarDate.today()
          ForEach(list.items) { certification in
            Button {
              opened = certification
            } label: {
              CertificationCardView(
                certificationUUID: certification.uuid,
                content: CertificationCardContent(certification, today: today))
            }
            .buttonStyle(.plain)
            .onAppear { Task { await list.loadMore(after: certification) } }
          }
          LoadMoreFooter(list: list)
        }
      }
      .padding()
    }
    .background(Color.pageBackground)
    .bubbleRefreshable { await list.refresh() }
    .navigationTitle(CertificationListView.title)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button(CertificationListView.newLabel, systemImage: "plus") { creating = true }
      }
    }
    .certificationSheet($opened)
    .navigationDestination(isPresented: $creating) {
      CertificationFormView(mode: .create)
    }
    .task { await list.showFollowingRoute(session) }
  }
}

#Preview {
  NavigationStack {
    CertificationListView()
  }
  .environment(Session.stub(transport: StubTransport(routes: [:])))
  .environment(OutboxModel(session: Session.stub(transport: StubTransport(routes: [:]))))
  .environment(InboxModel(session: Session.stub(transport: StubTransport(routes: [:]))))
}
