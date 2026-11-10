import OpenDivingKit
import SwiftUI

/// More's *Contacts*: what is waiting to sync, then the diver's contacts in the API's order, each
/// opening the contact's form, as a contact has no page, and holding *Delete* under a long press —
/// the pages the phone has shown first, from its copy.
struct ContactListView: View {
  @Environment(Session.self) private var session

  var body: some View {
    ContactListContent(model: ContactListModel(session: session))
  }
}

extension ContactListView {
  static let title = "Contacts"
  static let description = "The dive centers, schools, shops and places you stayed, kept once"
  static let listTitle = "Contact List"
  static let emptyTitle = "No contacts yet"
  static let emptyMessage =
    "Add the dive centers, shops and places you stay at once, and pick them from your dives, courses and trips."
  static let emptyAction = "Add your first contact"

  /// What a failed first page says: offline, that it shows once it can be read.
  static func failure(_ error: APIError) -> String {
    error.isUnreachable
      ? OfflineText.contactsNotShown : "Failed to load contacts. Please try again."
  }
}

/// Where the list pushes a contact's form.
private enum ContactFormRoute: Hashable {
  case create
  case edit(ContactRead)
}

private struct ContactListContent: View {
  @State var model: ContactListModel
  @Environment(OutboxModel.self) private var outbox
  @State private var route: ContactFormRoute?
  @State private var deleting: ContactRead?
  @State private var queueError: String?

  var body: some View {
    ScrollView {
      LazyVStack(spacing: 12) {
        Text(ContactListView.description)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .leading)
        // A queued create is not a row until it lands; what waits shows here however the
        // list stands.
        PendingSection()
        contacts
      }
      .padding()
    }
    .background(Color.pageBackground)
    .bubbleRefreshable { await model.refresh() }
    .navigationTitle(ContactListView.title)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button("New contact", systemImage: "plus") { route = .create }
      }
    }
    .navigationDestination(item: $route) { route in
      switch route {
      case .create: ContactFormView(mode: .create)
      case .edit(let contact): ContactFormView(mode: .edit(contact))
      }
    }
    .confirmationDialog(
      "Delete contact",
      isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
      titleVisibility: .visible, presenting: deleting
    ) { contact in
      Button("Delete", role: .destructive) {
        queueError = ContactListModel.delete(contact.uuid, in: outbox)
      }
    } message: { _ in
      Text(RecordDeletionText.contact)
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

  @ViewBuilder private var contacts: some View {
    let list = model.contacts
    switch list.phase {
    case .idle, .loading:
      EmptyOrErrorView(status: .loading)
        .padding(.top, 32)
    case .failed(let error):
      EmptyOrErrorView(status: .failed(message: ContactListView.failure(error))) {
        Task { await list.refresh() }
      }
    case .loaded where list.items.isEmpty:
      ContentUnavailableView {
        Label(ContactListView.emptyTitle, icon: .bookUser)
      } description: {
        Text(ContactListView.emptyMessage)
      } actions: {
        Button(ContactListView.emptyAction, systemImage: "plus") { route = .create }
          .brandProminentButton()
      }
    case .loaded:
      HStack(spacing: 8) {
        Image(.bookUser)
          .foregroundStyle(.secondary)
          .accessibilityHidden(true)
        Text(ContactListView.listTitle)
          .font(.headline)
          .accessibilityAddTraits(.isHeader)
        Spacer()
      }
      if let lastUpdated = list.lastUpdated {
        LastUpdatedLine(date: lastUpdated)
      }
      ForEach(list.items) { contact in
        Button {
          route = .edit(contact)
        } label: {
          PlainCardView(content: .contact(contact))
        }
        .buttonStyle(.plain)
        .contextMenu {
          Button("Delete", systemImage: "trash", role: .destructive) { deleting = contact }
        }
        .task { await list.loadMore(after: contact) }
      }
      LoadMoreFooter(list: list)
    }
  }
}

#Preview {
  NavigationStack {
    ContactListView()
  }
  .environment(DivePreviewData.session)
  .environment(OutboxModel(session: DivePreviewData.session))
  .environment(InboxModel(session: DivePreviewData.session))
}
