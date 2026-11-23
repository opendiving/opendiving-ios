import OpenDivingKit
import SwiftUI

/// More's *Contacts*: what is waiting to sync, then the diver's contacts on one card under the
/// letters they start with, an index of every letter at the trailing edge to jump between them.
/// Each opens the contact's form, as a contact has no page — the pages the phone has shown first,
/// from its copy.
struct ContactListView: View {
  @Environment(Session.self) private var session

  var body: some View {
    ContactListContent(model: ContactListModel(session: session))
  }
}

extension ContactListView {
  static let title = "Contacts"
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
  @State private var route: ContactFormRoute?

  var body: some View {
    let sections =
      model.contacts.phase == .loaded ? LetterIndex.sections(model.contacts.items) { $0.name } : []
    let indexed = sections.count > 1
    ScrollViewReader { scroller in
      ScrollView {
        VStack(spacing: 12) {
          // A queued create is not a row until it lands; what waits shows here however the
          // list stands.
          PendingSection()
          contacts(sections)
        }
        .padding()
      }
      // In the page's trailing margin, beside the card rather than over its rows.
      .overlay(alignment: .trailing) {
        if indexed {
          LetterIndexBar(column: LetterIndexColumn(filed: sections.map(\.letter))) { letter in
            scroller.scrollTo(letter, anchor: .top)
          }
          .padding(.vertical, 16)
        }
      }
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
    .task { await model.show() }
  }

  @ViewBuilder private func contacts(_ sections: [LetterSection<ContactRead>]) -> some View {
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
      if let lastUpdated = list.lastUpdated {
        LastUpdatedLine(date: lastUpdated)
      }
      // Lazy, so the last row asks for the next page only as it scrolls into view.
      LazyVStack(alignment: .leading, spacing: 0) {
        ForEach(Array(sections.enumerated()), id: \.element.id) { index, section in
          if index > 0 { Divider() }
          ListLetterHeader(letter: section.letter)
            .id(section.letter)
          ForEach(Array(section.items.enumerated()), id: \.element.id) { index, contact in
            if index > 0 {
              Divider().padding(.leading, ListRowIcon.textInset)
            }
            Button {
              route = .edit(contact)
            } label: {
              ContactRow(content: .contact(contact))
            }
            .buttonStyle(.plain)
            .task { await list.loadMore(after: contact) }
          }
        }
      }
      .background(Color.cardFill, in: .formSection)
      .clipShape(.formSection)
      LoadMoreFooter(list: list)
    }
  }
}

/// A contact's row on the list's card: the building icon in its circle, then its name with its
/// roles beside it, its city under them.
private struct ContactRow: View {
  let content: PlainCardContent

  var body: some View {
    HStack(spacing: 12) {
      ListRowIcon(icon: .building2)
      VStack(alignment: .leading, spacing: 2) {
        FlowLayout(spacing: 8, lineSpacing: 4) {
          Text(content.title)
            .font(.headline)
          ForEach(Array(content.badges.enumerated()), id: \.offset) { _, badge in
            BadgeView(badge)
          }
        }
        FactsLine(facts: content.facts, color: .primary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(12)
    .contentShape(.rect)
    .accessibilityElement(children: .combine)
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
