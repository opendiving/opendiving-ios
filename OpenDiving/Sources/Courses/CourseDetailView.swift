import OpenDivingKit
import SwiftUI

/// A course's page, by its uuid: its head, the certifications it issued, its dives and its
/// *Course Information* card, which logs a dive for it and adds a certification. It is edited
/// and deleted from its top bar.
struct CourseDetailView: View {
  let courseUUID: UUID
  @Environment(Session.self) private var session

  var body: some View {
    CourseDetailContent(
      model: CourseDetailModel(session: session, courseUUID: courseUUID),
      lookups: LookupsModel(session: session))
  }
}

extension CourseDetailView {
  static let notFound = "Course not found."
  static let certificationsTitle = "Certifications from This Course"
  static let certificationsDescription =
    "The cards this training issued. An existing card can name this course from its own form too."
  static let certificationsEmptyTitle = "No certifications from this course yet"
  static let certificationsEmptyMessage =
    "Add the card this training issued, or name this course from an existing card's form."
  static let certificationsEmptyAction = "Add the first certification"

  /// What a page that could not be read says: offline, that it shows once it can be.
  static func failure(_ error: APIError) -> String {
    error.isUnreachable ? OfflineText.courseNotShown : error.message
  }
}

private struct CourseDetailContent: View {
  @Environment(Session.self) private var session
  @Environment(OutboxModel.self) private var outbox
  @Environment(\.dismiss) private var dismiss
  @State private var model: CourseDetailModel
  @State private var lookups: LookupsModel

  @State private var confirmsDelete = false
  @State private var queueError: String?

  init(model: CourseDetailModel, lookups: LookupsModel) {
    _model = State(initialValue: model)
    _lookups = State(initialValue: lookups)
  }

  var body: some View {
    Group {
      switch model.page.phase {
      case .loading:
        EmptyOrErrorView(status: .loading)
      case .notFound:
        EmptyOrErrorView(status: .notFound(message: CourseDetailView.notFound))
      case .failed(let error):
        EmptyOrErrorView(status: .failed(message: CourseDetailView.failure(error))) {
          Task { await model.load() }
        }
      case .loaded(let course):
        ScrollView {
          LazyVStack(spacing: 16) {
            HeroView(content: CoursePageContent.hero(course))
            Group {
              if let lastUpdated = model.page.lastUpdated {
                LastUpdatedLine(date: lastUpdated)
              }
              if model.page.hasPendingEdit {
                PendingEditLine()
              }
              CourseCertificationsSection(course: course, list: model.certifications)
              RecordDivesSection(
                list: model.dives, content: .course, units: session.units,
                logDive: .course(course.uuid))
              CourseInformationCard(
                course: course,
                information: CoursePageContent.information(
                  course, people: session.people, personLookups: lookups.people,
                  contactLookups: lookups.contacts))
            }
            .padding(.horizontal)
          }
          .padding(.bottom)
        }
        .heroUnderTopBar { await model.refresh() }
        .toolbar { actions(course) }
        .confirmationDialog(
          "Delete course", isPresented: $confirmsDelete, titleVisibility: .visible
        ) {
          Button("Delete", role: .destructive) {
            queueError = CourseDetailModel.delete(course.uuid, in: outbox)
            if queueError == nil { dismiss() }
          }
        } message: {
          Text(RecordDeletionText.course)
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

  @ToolbarContentBuilder private func actions(_ course: CourseRead) -> some ToolbarContent {
    ToolbarItemGroup(placement: .topBarTrailing) {
      NavigationLink {
        CourseFormView(mode: .edit(course)) { dismiss() }
      } label: {
        Label("Edit", systemImage: "pencil")
      }
      Menu {
        Button("Delete", systemImage: "trash", role: .destructive) { confirmsDelete = true }
      } label: {
        Label("Actions for " + course.name, systemImage: "ellipsis")
      }
    }
  }

  private var title: String {
    if case .loaded(let course) = model.page.phase { course.name } else { "Course" }
  }
}

/// The certifications the course issued, each opening its page. A course with no agency and no
/// card shows nothing; one with an agency and no card invites the first.
private struct CourseCertificationsSection: View {
  let course: CourseRead
  let list: PagedList<CertificationRead>

  var body: some View {
    if CoursePageContent.showsCertifications(course, certifications: list.items) {
      switch list.phase {
      case .idle, .loading:
        card {
          BubbleSpinner()
            .frame(maxWidth: .infinity)
        }
      case .failed(let error) where error.isUnreachable:
        card {
          Text(OfflineText.certificationsNotShown)
            .font(.subheadline)
            .foregroundStyle(.secondary)
          Button("Try again") { Task { await list.load() } }
            .buttonStyle(.bordered)
        }
      // The web leaves a list it could not read empty, which invites the first card.
      case .failed:
        empty
      case .loaded where list.items.isEmpty:
        empty
      case .loaded:
        card {
          ForEach(list.items) { certification in
            NavigationLink {
              CertificationDetailView(certificationUUID: certification.uuid)
            } label: {
              VStack(alignment: .leading, spacing: 2) {
                Text(certification.name)
                  .font(.body.weight(.medium))
                Text(CoursePageContent.certificationLine(certification))
                  .font(.subheadline)
                  .foregroundStyle(.secondary)
              }
              .frame(maxWidth: .infinity, alignment: .leading)
              .contentShape(.rect)
            }
            .buttonStyle(.plain)
          }
        }
      }
    }
  }

  private var empty: some View {
    ContentUnavailableView {
      Label(CourseDetailView.certificationsEmptyTitle, icon: .badgeCheck)
    } description: {
      Text(CourseDetailView.certificationsEmptyMessage)
    } actions: {
      NavigationLink {
        CertificationFormView(mode: .create, course: course)
      } label: {
        Label(CourseDetailView.certificationsEmptyAction, systemImage: "plus")
      }
      .brandProminentButton()
    }
  }

  private func card(@ViewBuilder _ rows: () -> some View) -> some View {
    SectionCard(title: CourseDetailView.certificationsTitle, icon: .badgeCheck) {
      Text(CourseDetailView.certificationsDescription)
        .font(.subheadline)
        .foregroundStyle(.secondary)
      rows()
    }
  }
}

/// The dive centre, the instructor and their number, the people on the course and its notes,
/// each where the course holds it and the phone holds its name, then *Log a dive* and
/// *Add a certification*.
private struct CourseInformationCard: View {
  let course: CourseRead
  let information: CoursePageContent.Information

  var body: some View {
    SectionCard(title: "Course Information", icon: .graduationCap) {
      VStack(alignment: .leading, spacing: 16) {
        if let diveCenter = information.diveCenter {
          InfoRow(label: "Dive center") { Text(diveCenter) }
        }
        if let instructor = information.instructor {
          InfoRow(label: "Instructor") {
            if let uuid = instructor.uuid {
              NavigationLink(instructor.name) { PersonDetailView(personUUID: uuid) }
            } else {
              Text(instructor.name)
            }
          }
        }
        if let number = information.instructorNumber {
          InfoRow(label: "Instructor number") { Text(number) }
        }
        if !information.people.isEmpty {
          InfoRow(label: "People") {
            VStack(alignment: .leading, spacing: 8) {
              ForEach(Array(information.people.enumerated()), id: \.offset) { _, person in
                PersonRowView(content: person)
              }
            }
          }
        }
        if let notes = information.notes {
          InfoRow(label: "Notes") { Text(notes) }
        }
        VStack(spacing: 8) {
          NavigationLink {
            DiveFormView(mode: .course(course.uuid))
          } label: {
            Label("Log a dive", systemImage: "plus")
              .frame(maxWidth: .infinity)
          }
          .brandProminentButton()
          NavigationLink {
            CertificationFormView(mode: .create, course: course)
          } label: {
            Label("Add a certification", icon: .badgeCheck)
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.bordered)
        }
      }
    }
  }
}

#Preview {
  NavigationStack {
    CourseDetailView(courseUUID: UUID())
  }
  .environment(DivePreviewData.session)
  .environment(OutboxModel(session: DivePreviewData.session))
}
