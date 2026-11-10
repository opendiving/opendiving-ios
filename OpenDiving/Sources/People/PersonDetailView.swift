import OpenDivingKit
import SwiftUI

/// A person's page, by their uuid: their name and username, their email and phone opening Mail
/// and the dialler, the dives together and their notes. They are edited and deleted from the top
/// bar.
struct PersonDetailView: View {
  let personUUID: UUID
  @Environment(Session.self) private var session

  var body: some View {
    PersonDetailContent(model: PersonDetailModel(session: session, personUUID: personUUID))
  }
}

extension PersonDetailView {
  static let notFound = "Person not found."

  /// What a page that could not be read says: offline, that it shows once it can be.
  static func failure(_ error: APIError) -> String {
    error.isUnreachable ? OfflineText.personNotShown : error.message
  }
}

private struct PersonDetailContent: View {
  @Environment(Session.self) private var session
  @Environment(OutboxModel.self) private var outbox
  @Environment(\.dismiss) private var dismiss
  @State private var model: PersonDetailModel

  @State private var confirmsDelete = false
  @State private var queueError: String?

  init(model: PersonDetailModel) {
    _model = State(initialValue: model)
  }

  var body: some View {
    Group {
      switch model.page.phase {
      case .loading:
        EmptyOrErrorView(status: .loading)
      case .notFound:
        EmptyOrErrorView(status: .notFound(message: PersonDetailView.notFound))
      case .failed(let error):
        EmptyOrErrorView(status: .failed(message: PersonDetailView.failure(error))) {
          Task { await model.load() }
        }
      case .loaded(let person):
        ScrollView {
          LazyVStack(spacing: 16) {
            HeroView(content: PersonPageContent.hero(person))
            Group {
              PersonReachLinks(
                email: PersonPageContent.email(person), phone: PersonPageContent.phone(person))
              if let lastUpdated = model.page.lastUpdated {
                LastUpdatedLine(date: lastUpdated)
              }
              if model.page.hasPendingEdit {
                PendingEditLine()
              }
              RecordDivesSection(
                list: model.dives, content: .person, units: session.units, logDive: .create)
              if let notes = PersonPageContent.notes(person) {
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
        .toolbar { actions(person) }
        .confirmationDialog(
          "Delete person", isPresented: $confirmsDelete, titleVisibility: .visible
        ) {
          Button("Delete", role: .destructive) {
            queueError = PeopleListModel.delete(person.uuid, in: outbox)
            if queueError == nil { dismiss() }
          }
        } message: {
          Text(RecordDeletionText.person)
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

  @ToolbarContentBuilder private func actions(_ person: PersonRead) -> some ToolbarContent {
    ToolbarItemGroup(placement: .topBarTrailing) {
      NavigationLink {
        PersonFormView(mode: .edit(person))
      } label: {
        Label("Edit", systemImage: "pencil")
      }
      Menu {
        Button("Delete", systemImage: "trash", role: .destructive) { confirmsDelete = true }
      } label: {
        Label("Actions for " + person.name, systemImage: "ellipsis")
      }
    }
  }

  private var title: String {
    if case .loaded(let person) = model.page.phase { person.name } else { "Person" }
  }
}

/// The person's email and phone under the head, each opening Mail or the dialler where it makes a
/// link.
private struct PersonReachLinks: View {
  let email: PersonPageContent.Reach?
  let phone: PersonPageContent.Reach?

  var body: some View {
    if email != nil || phone != nil {
      VStack(alignment: .leading, spacing: 8) {
        if let email { reach(email, icon: .mail) }
        if let phone { reach(phone, icon: .phone) }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  @ViewBuilder private func reach(_ reach: PersonPageContent.Reach, icon: Icon) -> some View {
    if let url = reach.url {
      Link(destination: url) { Label(reach.text, icon: icon) }
        .accentRow()
    } else {
      Label(reach.text, icon: icon)
    }
  }
}

#Preview {
  NavigationStack {
    PersonDetailView(personUUID: UUID())
  }
  .environment(DivePreviewData.session)
  .environment(OutboxModel(session: DivePreviewData.session))
}
