import OpenDivingKit
import SwiftUI
import UIKit

/// More's *Certifications*: the diver's c-cards, newest certified first, each over its front
/// image at the card's shape and opening its page — the pages the phone has shown first, from its
/// copy. A card being created waits in the pending summary above them.
struct CertificationListView: View {
  @Environment(Session.self) private var session

  var body: some View {
    CertificationListContent(list: .certifications(session))
  }
}

extension CertificationListView {
  static let title = "Certifications"
  static let description =
    "Keep photos of your c-cards here, so they're on hand at the dive shop without digging out the plastic"
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

  var body: some View {
    ScrollView {
      LazyVStack(spacing: 12) {
        Text(CertificationListView.description)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .leading)
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
            NavigationLink {
              CertificationDetailView(certificationUUID: certification.uuid)
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
    .navigationDestination(isPresented: $creating) {
      CertificationFormView(mode: .create)
    }
    .task { await list.showFollowingRoute(session) }
  }
}

/// One certification as a card: its front behind the details, in the card's shape so the front
/// shows whole, or the water and an icon where there is no picture to show — none stored, a PDF,
/// or one that could not be had. Nothing while the picture is on its way, so a card that has one
/// does not flash an icon first.
private struct CertificationCardView: View {
  let certificationUUID: UUID
  let content: CertificationCardContent

  @Environment(Session.self) private var session
  @State private var front: UIImage?
  @State private var loading = true

  var body: some View {
    Color.clear
      .aspectRatio(CertificationCardCrop.aspect, contentMode: .fit)
      .frame(maxWidth: .infinity)
      .background { backdrop }
      .overlay(alignment: .bottom) { details }
      .background(Color(.systemBackground))
      .clipShape(.formSection)
      .accessibilityElement(children: .combine)
      .task(id: content.front) { await load() }
  }

  @ViewBuilder private var backdrop: some View {
    if let front {
      Image(uiImage: front)
        .resizable()
        .scaledToFill()
        .accessibilityHidden(true)
    } else if !loading {
      UnplacedBackdropView(icon: content.missingFrontIcon, coveredBottom: 100)
    }
  }

  private var details: some View {
    VStack(alignment: .leading, spacing: 6) {
      FlowLayout(spacing: 8, lineSpacing: 4) {
        Text(content.name)
          .font(.headline)
        if let expiry = content.expiry {
          BadgeView(expiry.label, style: expiry == .expired ? .destructive : .coral)
        }
      }
      if let agency = content.agency {
        Text(agency)
          .font(.caption)
      }
      FiguresRow(figures: content.figures, minWidth: 120)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(CardBackdropFrame.glassPadding)
    .background { GlassCard(shape: .formSection(inset: CardBackdropFrame.glassInset)) }
    .padding(CardBackdropFrame.glassInset)
  }

  private func load() async {
    guard let file = content.front else {
      front = nil
      loading = false
      return
    }
    loading = true
    let bytes = await CertificationCardImages.bytes(
      of: certificationUUID, file, session: session)
    front = bytes.flatMap(UIImage.init(data:))
    loading = false
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
