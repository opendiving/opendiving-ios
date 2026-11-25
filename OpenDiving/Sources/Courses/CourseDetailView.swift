import OpenDivingKit
import SwiftUI

/// A course's page, by its uuid: its head, then three tabs — Info, its information card over
/// *Add dives* and *Add certifications*; Certifications, the cards it issued; and Dives, those
/// logged on it. Its top bar opens its form, which also deletes it.
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
  static let certificationsEmptyMessage = "Add the cards this training issued to see them here."
  /// The Info tab's buttons, which the empty Dives and Certifications tabs repeat.
  static let addDives = "Add dives"
  static let addCertifications = "Add certifications"

  /// What a page that could not be read says: offline, that it shows once it can be.
  static func failure(_ error: APIError) -> String {
    error.isUnreachable ? OfflineText.courseNotShown : error.message
  }
}

private struct CourseDetailContent: View {
  @Environment(Session.self) private var session
  @Environment(\.dismiss) private var dismiss
  @State private var model: CourseDetailModel
  @State private var lookups: LookupsModel

  @State private var section = CourseSection.info
  @State private var scroll = ScrollPosition(edge: .top)
  @State private var tabsTop: CGFloat = 0
  @State private var tabsStuck = false
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
            ScrollingSectionTabs(
              selection: $section, isStuck: $tabsStuck, top: $tabsTop, title: tabTitle,
              onReselect: scrollOnReselect)
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
                  list: model.dives, content: .course, units: session.units, isCarded: false
                ) {
                  CourseAddLink(kind: .dives, course: course)
                }
              }
            }
            .padding(.horizontal)
            .hiddenUnderTopBar()
          }
          .coordinateSpace(.pageContent)
          .padding(.bottom)
        }
        .scrollPosition($scroll)
        .tabsReselect($reselect, tabsTop: tabsTop)
        .overlay(alignment: .top) {
          StuckSectionTabs(
            selection: $section, isStuck: tabsStuck, title: tabTitle, onReselect: scrollOnReselect)
        }
        .heroUnderTopBar { await model.refresh() }
        .toolbar { actions(course) }
      }
    }
    .background(Color.pageBackground)
    .navigationTitle(title)
    .navigationBarTitleDisplayMode(.inline)
    // The title names the page in the back button's history; the head says it on screen.
    .toolbar(removing: .title)
    .task {
      await model.load()
      await model.followRoute()
    }
  }

  @ToolbarContentBuilder private func actions(_ course: CourseRead) -> some ToolbarContent {
    ToolbarItem(placement: .topBarTrailing) {
      NavigationLink {
        CourseFormView(mode: .edit(course)) { dismiss() }
      } label: {
        Label("Edit", systemImage: "pencil")
      }
    }
  }

  private func tabTitle(_ section: CourseSection) -> String {
    switch section {
    case .info: section.title
    case .certifications: DiveSiteSummary.counted(section.title, model.certifications.count ?? 0)
    case .dives: DiveSiteSummary.counted(section.title, model.dives.count ?? 0)
    }
  }

  private func scrollOnReselect() {
    withAnimation { scroll.scroll(to: reselect) }
  }

  private var title: String {
    if case .loaded(let course) = model.page.phase { course.name } else { "Course" }
  }
}

/// The certifications the course issued, a card each as More's *Certifications* draws them, each
/// opening its pane; while it has none, the Info tab's *Add certifications*. A course with no
/// agency offers it too, where the web hides its card: the tab is there for every course, and the
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
      CourseAddLink(kind: .certifications, course: course)
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
        person, icon: .instructor, picture: person?.picture, title: person?.name ?? number ?? "",
        detail: [
          person?.username.map { "@" + $0 }, "Instructor", person == nil ? nil : number,
        ].compactMap { $0 }.joined(separator: " · "))
    case .person(let person):
      personRow(
        person, icon: .user, picture: person.picture, title: person.name,
        detail: [person.username.map { "@" + $0 }, person.role].compactMap { $0 }
          .joined(separator: " · "))
    case .notes(let notes):
      CourseInformationRow(icon: .fileText, title: notes)
    }
  }

  @ViewBuilder private func personRow(
    _ person: PersonRowContent?, icon: Icon, picture: ConnectedPicture? = nil, title: String,
    detail: String?
  ) -> some View {
    let detail = detail?.isEmpty == true ? nil : detail
    if let uuid = person?.uuid {
      NavigationLink {
        PersonDetailView(personUUID: uuid)
      } label: {
        CourseInformationRow(
          icon: icon, picture: picture, title: title, detail: detail, opens: true)
      }
      .buttonStyle(.plain)
    } else {
      CourseInformationRow(icon: icon, picture: picture, title: title, detail: detail)
    }
  }
}

/// One of the information card's rows: its icon, the value with a line under it where it has
/// one, and a chevron where the row opens a page.
private struct CourseInformationRow: View {
  let icon: Icon
  /// A connected person's picture, drawn in the icon's place and at its size.
  var picture: ConnectedPicture?
  let title: String
  var detail: String?
  var opens = false

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 12) {
      IconOrConnectedPicture(icon: icon, picture: picture)
        .frame(width: 24)
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

/// *Add dives* beside *Add certifications*, each opening a list of the diver's records to put on
/// the course: each button as wide as its label plus an equal share of what is left of the row,
/// so both keep the same padding. Over it where the row leaves no room.
private struct CourseActions: View {
  let course: CourseRead

  var body: some View {
    ViewThatFits(in: .horizontal) {
      EqualPaddingRow(spacing: 8) { buttons }
      VStack(spacing: 8) { buttons }
    }
  }

  @ViewBuilder private var buttons: some View {
    CourseAddLink(kind: .dives, course: course, fillsWidth: true)
    CourseAddLink(kind: .certifications, course: course, fillsWidth: true)
  }
}

/// *Add dives*, in the coral the profile's own *Log a dive* takes, or *Add certifications*: the
/// Info tab's pair, as wide as their row gives them, or an empty tab's own, as wide as its label
/// and a little more at its ends, which on iOS 26 otherwise have less room than its icon and its
/// words have between them.
private struct CourseAddLink: View {
  enum Kind { case dives, certifications }

  let kind: Kind
  let course: CourseRead
  var fillsWidth = false

  var body: some View {
    switch kind {
    case .dives:
      NavigationLink {
        CourseAddDivesView(course: course)
      } label: {
        label(CourseDetailView.addDives, icon: .dive)
      }
      .brandProminentButton(.brandCoral)
    case .certifications:
      NavigationLink {
        CourseAddCertificationsView(course: course)
      } label: {
        label(CourseDetailView.addCertifications, icon: .badgeCheck)
      }
      .brandBorderedButton()
    }
  }

  private func label(_ title: String, icon: Icon) -> some View {
    Label(title, icon: icon)
      .frame(maxWidth: fillsWidth ? .infinity : nil)
      .padding(.horizontal, fillsWidth ? 0 : 4)
  }
}

/// Its views side by side across the row, each as wide as it would be alone plus an equal share
/// of the width left over, where an `HStack` of flexible views gives each an equal width instead.
/// Its ideal width is its views' own, so a `ViewThatFits` passes it over when they do not fit.
private struct EqualPaddingRow: Layout {
  var spacing: CGFloat

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
    let natural = sizes.reduce(0) { $0 + $1.width } + gaps(subviews)
    return CGSize(width: proposal.width ?? natural, height: sizes.map(\.height).max() ?? 0)
  }

  func placeSubviews(
    in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
  ) {
    let widths = subviews.map { $0.sizeThatFits(.unspecified).width }
    let left = bounds.width - widths.reduce(0, +) - gaps(subviews)
    let share = max(left, 0) / CGFloat(max(subviews.count, 1))
    var x = bounds.minX
    for (subview, width) in zip(subviews, widths) {
      subview.place(
        at: CGPoint(x: x, y: bounds.midY), anchor: .leading,
        proposal: ProposedViewSize(width: width + share, height: bounds.height))
      x += width + share + spacing
    }
  }

  private func gaps(_ subviews: Subviews) -> CGFloat {
    spacing * CGFloat(max(subviews.count - 1, 0))
  }
}

#Preview {
  NavigationStack {
    CourseDetailView(courseUUID: UUID())
  }
  .environment(DivePreviewData.session)
  .environment(OutboxModel(session: DivePreviewData.session))
}
