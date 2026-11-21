import OpenDivingKit
import SwiftUI

/// A course's page, by its uuid: its head, then three tabs — Info, its information card over
/// *Log a dive* and *Add a certification*; Certifications, the cards it issued; and Dives, those
/// logged on it. It is edited and deleted from its top bar.
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
  @State private var section = CourseSection.info
  @State private var scroll = ScrollPosition(edge: .top)
  @State private var tabsTop: CGFloat = 0
  @State private var reselect = TabsReselect.head

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
            HeroView(content: CoursePageContent.hero(course), backdrop: .plain)
            if model.page.lastUpdated != nil || model.page.hasPendingEdit {
              VStack(spacing: 16) {
                if let lastUpdated = model.page.lastUpdated {
                  LastUpdatedLine(date: lastUpdated)
                }
                if model.page.hasPendingEdit {
                  PendingEditLine()
                }
              }
              .padding(.horizontal)
            }
            SectionTabs(
              selection: $section,
              title: { section in
                switch section {
                case .info: section.title
                case .certifications:
                  DiveSiteSummary.counted(section.title, model.certifications.count ?? 0)
                case .dives: DiveSiteSummary.counted(section.title, model.dives.count ?? 0)
                }
              },
              onReselect: { withAnimation { scroll.scroll(to: reselect) } }
            )
            .readsTabsTop($tabsTop)
            Group {
              switch section {
              case .info:
                CourseInformationCard(
                  information: CoursePageContent.information(
                    course, people: session.people, personLookups: lookups.people,
                    contactLookups: lookups.contacts))
                CourseActions(course: course)
              case .certifications:
                CourseCertificationsSection(course: course, list: model.certifications)
              case .dives:
                RecordDivesSection(
                  list: model.dives, content: .course, units: session.units,
                  logDive: .course(course.uuid), isCarded: false)
              }
            }
            .padding(.horizontal)
          }
          .coordinateSpace(.pageContent)
          .padding(.bottom)
        }
        .scrollPosition($scroll)
        .tabsReselect($reselect, tabsTop: tabsTop)
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

/// The certifications the course issued, a card each as More's *Certifications* draws them, each
/// opening its pane; while it has none, an invitation to add the first. A course with no agency
/// invites one too, where the web hides its card: the tab is there for every course, and the
/// diver who opens it is asking for its cards.
private struct CourseCertificationsSection: View {
  let course: CourseRead
  let list: PagedList<CertificationRead>

  @State private var opened: CertificationRead?

  var body: some View {
    section.certificationSheet($opened)
  }

  @ViewBuilder private var section: some View {
    switch list.phase {
    case .idle, .loading:
      BubbleSpinner()
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    case .failed(let error) where error.isUnreachable:
      EmptyOrErrorView(status: .failed(message: OfflineText.certificationsNotShown)) {
        Task { await list.load() }
      }
    // The web leaves a list it could not read empty, which invites the first card.
    case .failed:
      empty
    case .loaded where list.items.isEmpty:
      empty
    case .loaded:
      let today = CalendarDate.today()
      LazyVStack(spacing: 12) {
        ForEach(list.items) { certification in
          Button {
            opened = certification
          } label: {
            CertificationCardView(
              certificationUUID: certification.uuid,
              content: CertificationCardContent(certification, today: today))
          }
          .buttonStyle(.plain)
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
}

/// The dive centre, the instructor and their number, the people on the course and its notes, a
/// row each on one card led by its icon, each where the course holds it and the phone holds its
/// name. A person the server has opens their page. Nothing at all where the course holds none.
private struct CourseInformationCard: View {
  let information: CoursePageContent.Information

  private enum Row: Hashable {
    case diveCenter(String)
    case instructor(PersonRowContent?, number: String?)
    case person(PersonRowContent)
    case notes(String)
  }

  private var rows: [Row] {
    var rows: [Row] = []
    if let diveCenter = information.diveCenter { rows.append(.diveCenter(diveCenter)) }
    if information.instructor != nil || information.instructorNumber != nil {
      rows.append(.instructor(information.instructor, number: information.instructorNumber))
    }
    rows += information.people.map(Row.person)
    if let notes = information.notes { rows.append(.notes(notes)) }
    return rows
  }

  var body: some View {
    let rows = rows
    if !rows.isEmpty {
      VStack(spacing: 0) {
        ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
          if index > 0 {
            Divider().padding(.leading, 52)
          }
          view(row)
        }
      }
      .background(Color.cardFill, in: .formSection)
    }
  }

  @ViewBuilder private func view(_ row: Row) -> some View {
    switch row {
    case .diveCenter(let name):
      CourseInformationRow(icon: .building2, title: name)
    case .instructor(let person, let number):
      // A number with no name the phone holds stands in the name's place.
      personRow(
        person, icon: .instructor, title: person?.name ?? number ?? "",
        detail: ["Instructor", person == nil ? nil : number].compactMap { $0 }
          .joined(separator: " · "))
    case .person(let person):
      personRow(
        person, icon: .user, title: person.name,
        detail: [person.username.map { "@" + $0 }, person.role].compactMap { $0 }
          .joined(separator: " · "))
    case .notes(let notes):
      CourseInformationRow(icon: .fileText, title: notes)
    }
  }

  @ViewBuilder private func personRow(
    _ person: PersonRowContent?, icon: Icon, title: String, detail: String?
  ) -> some View {
    let detail = detail?.isEmpty == true ? nil : detail
    if let uuid = person?.uuid {
      NavigationLink {
        PersonDetailView(personUUID: uuid)
      } label: {
        CourseInformationRow(icon: icon, title: title, detail: detail, opens: true)
      }
      .buttonStyle(.plain)
    } else {
      CourseInformationRow(icon: icon, title: title, detail: detail)
    }
  }
}

/// One of the information card's rows: its icon, the value with a line under it where it has
/// one, and a chevron where the row opens a page.
private struct CourseInformationRow: View {
  let icon: Icon
  let title: String
  var detail: String?
  var opens = false

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 12) {
      Image(icon)
        .foregroundStyle(.secondary)
        .frame(width: 24)
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
        if let detail {
          Text(detail)
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      if opens {
        Image(systemName: "chevron.right")
          .font(.footnote.weight(.semibold))
          .foregroundStyle(.tertiary)
          .accessibilityHidden(true)
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .frame(minHeight: 48)
    .contentShape(Rectangle())
    .accessibilityElement(children: .combine)
  }
}

/// *Log a dive* on the course, in the coral the profile's own *Log a dive* takes, beside *Add a
/// certification* — words alone, so the two share a row — and over it where a large text size
/// leaves no room.
private struct CourseActions: View {
  let course: CourseRead

  var body: some View {
    ViewThatFits(in: .horizontal) {
      HStack(spacing: 8) { buttons }
      VStack(spacing: 8) { buttons }
    }
  }

  @ViewBuilder private var buttons: some View {
    NavigationLink {
      DiveFormView(mode: .course(course.uuid))
    } label: {
      Text("Log a dive")
        .frame(maxWidth: .infinity)
    }
    .brandProminentButton(.brandCoral)
    NavigationLink {
      CertificationFormView(mode: .create, course: course)
    } label: {
      Text("Add a certification")
        .frame(maxWidth: .infinity)
    }
    .brandBorderedButton()
  }
}

#Preview {
  NavigationStack {
    CourseDetailView(courseUUID: UUID())
  }
  .environment(DivePreviewData.session)
  .environment(OutboxModel(session: DivePreviewData.session))
}
