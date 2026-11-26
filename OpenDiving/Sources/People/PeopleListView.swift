import OpenDivingKit
import SwiftUI

/// More's *People*: what is waiting to sync, then *Added you* where anybody has added the diver,
/// then the diver's people on one card, filed under their letters with an index of every letter
/// down the edge as Contacts has, each opening their page — the pages the phone has shown first,
/// from its copy.
struct PeopleListView: View {
  @Environment(Session.self) private var session

  var body: some View {
    PeopleListContent(
      model: PeopleListModel(session: session), addedYou: AddedYouModel(session: session))
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

private struct PeopleListContent: View {
  @State var model: PeopleListModel
  @State var addedYou: AddedYouModel
  @State private var creating = false

  var body: some View {
    let sections = model.people.phase == .loaded ? model.sections : []
    let indexed = sections.count > 1
    ScrollViewReader { proxy in
      ScrollView {
        LazyVStack(spacing: 12) {
          // A queued create is not a row until it lands; what waits shows here however the
          // list stands.
          PendingSection()
          AddedYouSection(model: addedYou)
          people(sections)
        }
        .padding()
      }
      // In the page's trailing margin, beside the card rather than over its rows.
      .overlay(alignment: .trailing) {
        if indexed {
          LetterIndexBar(column: LetterIndexColumn(filed: sections.map(\.letter))) { letter in
            proxy.scrollTo(letter, anchor: .top)
          }
          .padding(.vertical, 16)
        }
      }
    }
    .background(Color.pageBackground)
    .bubbleRefreshable {
      async let people: Void = model.refresh()
      await addedYou.refresh()
      await people
    }
    .navigationTitle(PeopleListView.title)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button("New person", systemImage: "plus") { creating = true }
      }
    }
    .navigationDestination(isPresented: $creating) { PersonFormView(mode: .create) }
    .task { await model.show() }
    .task { await addedYou.show() }
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
        Button(PeopleListView.emptyAction, systemImage: "plus") { creating = true }
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
          if index > 0 { ListRowDivider(leading: 12, trailing: 12) }
          ListSectionHeader(title: section.letter)
            .id(section.letter)
          ForEach(Array(section.people.enumerated()), id: \.element.id) { index, person in
            if index > 0 {
              ListRowDivider(leading: ListRowIcon.textInset, trailing: 12)
            }
            NavigationLink {
              PersonDetailView(personUUID: person.uuid)
            } label: {
              PersonListRow(
                content: .person(person), picture: PersonPageContent.picture(person))
            }
            .buttonStyle(.plain)
          }
        }
      }
      .background(Color.cardFill, in: .formSection)
      .clipShape(.formSection)
      LoadMoreFooter(list: list)
    }
  }
}

/// A person's row on the card: the connected account's picture, or the user icon, in its circle,
/// then their name over the connected account's username and how many dives name them.
private struct PersonListRow: View {
  let content: PlainCardContent
  let picture: ConnectedPicture?

  var body: some View {
    HStack(spacing: 12) {
      ConnectedPictureView(picture: picture, side: ListRowIcon.side)
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 2) {
        Text(content.title)
          .font(.headline)
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
    PeopleListView()
  }
  .environment(DivePreviewData.session)
  .environment(OutboxModel(session: DivePreviewData.session))
  .environment(InboxModel(session: DivePreviewData.session))
}
