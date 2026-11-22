import OpenDivingKit
import SwiftUI

/// More's *People*: what is waiting to sync, then the diver's people on one card, filed under
/// their letters with an index of them down the edge as Contacts has, each opening their page and
/// holding *Edit* and *Delete* under a long press — the pages the phone has shown first, from its
/// copy.
struct PeopleListView: View {
  @Environment(Session.self) private var session

  var body: some View {
    PeopleListContent(model: PeopleListModel(session: session))
  }
}

extension PeopleListView {
  static let title = "People"
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
    let sections = model.people.phase == .loaded ? model.sections : []
    ScrollViewReader { proxy in
      ScrollView {
        LazyVStack(spacing: 12) {
          // A queued create is not a row until it lands; what waits shows here however the
          // list stands.
          PendingSection()
          people(sections)
        }
        .padding()
      }
      // In the page's trailing margin, beside the card rather than over its rows.
      .overlay(alignment: .trailing) {
        if !sections.isEmpty {
          SectionIndexBar(letters: sections.map(\.letter)) { letter in
            proxy.scrollTo(letter, anchor: .top)
          }
        }
      }
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

  @ViewBuilder private func people(_ sections: [PeopleLetterSection]) -> some View {
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
      if let lastUpdated = list.lastUpdated {
        LastUpdatedLine(date: lastUpdated)
      }
      // Not lazy, so the index can scroll to a letter that has not been drawn yet; the model
      // reads every page rather than the rows asking for the next.
      VStack(spacing: 0) {
        ForEach(Array(sections.enumerated()), id: \.element.id) { index, section in
          if index > 0 { Divider() }
          PeopleLetterHeader(letter: section.letter)
            .id(section.letter)
          ForEach(Array(section.people.enumerated()), id: \.element.id) { index, person in
            if index > 0 {
              Divider().padding(.leading, PersonListRow.textInset)
            }
            NavigationLink {
              PersonDetailView(personUUID: person.uuid)
            } label: {
              PersonListRow(content: .person(person))
            }
            .buttonStyle(.plain)
            .contentShape(.contextMenuPreview, .formSection)
            .contextMenu {
              Button("Edit", systemImage: "pencil") { route = .edit(person) }
              Button("Delete", systemImage: "trash", role: .destructive) { deleting = person }
            }
          }
        }
      }
      .background(Color.cardFill, in: .formSection)
      .clipShape(.formSection)
      LoadMoreFooter(list: list)
    }
  }
}

/// The letter a run of the card's rows is filed under.
private struct PeopleLetterHeader: View {
  let letter: String

  var body: some View {
    Text(letter)
      .font(.subheadline.weight(.semibold))
      .foregroundStyle(.secondary)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 12)
      .padding(.top, 10)
      .padding(.bottom, 2)
      .accessibilityAddTraits(.isHeader)
  }
}

/// A person's row on the card: the user icon in its circle, then their name over the linked
/// account's username and how many dives name them.
private struct PersonListRow: View {
  let content: PlainCardContent

  private static let iconSide: CGFloat = 36
  /// Where the row's text starts, which the rule between two rows starts under.
  static let textInset: CGFloat = 12 + iconSide + 12

  var body: some View {
    HStack(spacing: 12) {
      UserAvatarView(initials: nil, picture: nil, side: Self.iconSide)
        .foregroundStyle(.secondary)
        .background(Color(.tertiarySystemFill), in: Circle())
      VStack(alignment: .leading, spacing: 2) {
        Text(content.title)
          .font(.headline)
        FactsLine(facts: content.facts, color: .primary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
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
    PeopleListView()
  }
  .environment(DivePreviewData.session)
  .environment(OutboxModel(session: DivePreviewData.session))
  .environment(InboxModel(session: DivePreviewData.session))
}
