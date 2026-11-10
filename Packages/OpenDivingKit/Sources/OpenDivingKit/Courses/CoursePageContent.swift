import Foundation

/// What a course's page says (`CourseDetailPageContent`): its head, the certifications it issued,
/// and its *Course Information* card.
public enum CoursePageContent {
  /// The agency and the dates, in the card's formats, so a course reads the same on its page as
  /// in the list; either is left out where the course lacks it.
  static func agencyAndDates(_ course: CourseRead) -> [String] {
    [
      VocabularyLabels.certificationAgency(course.agency, other: course.agencyOther),
      DateText.dateRange(start: course.startDate, end: course.endDate),
    ].compactMap { $0 }
  }

  /// The page's head: the name over the agency, the dates and the status.
  public static func hero(_ course: CourseRead) -> HeroContent {
    let status = RecordSheetText.courseStatus(course.status)
    let subtitle = agencyAndDates(course) + (status.isEmpty ? [] : [status])
    return HeroContent(title: course.name, facts: subtitle.map { Fact(text: $0) })
  }

  /// The status as its badge (`courseStatusBadgeVariant`): completed in the primary fill, the
  /// two unfinished outcomes in amber, a fail in red, and the rest — planned, under way, a
  /// status this build does not know — outlined.
  public static func statusBadge(_ status: String) -> Badge {
    let style: Badge.Style =
      switch status {
      case "completed": .primary
      case "incomplete", "provisional": .warning
      case "not_passed": .destructive
      default: .outline
      }
    return Badge(RecordSheetText.courseStatus(status), style: style)
  }

  /// Whether the page shows its certifications: a course with no agency, a private instructor's,
  /// usually issues no card, so its card waits for one rather than inviting it.
  public static func showsCertifications(_ course: CourseRead, certifications: [CertificationRead])
    -> Bool
  {
    !(course.agency ?? "").isEmpty || !certifications.isEmpty
  }

  /// A certification's row under the course: the agency, and the day it was certified where it
  /// has one.
  public static func certificationLine(_ certification: CertificationRead) -> String {
    [
      VocabularyLabels.certificationAgency(
        certification.agency, other: certification.agencyOther),
      certification.certifiedOn.map(DateText.date),
    ].compactMap { $0 }.joined(separator: " · ")
  }

  /// The *Course Information* card's rows, each nil or empty where the course holds nothing for
  /// it or the phone holds no name for it.
  public struct Information: Hashable, Sendable {
    public var diveCenter: String?
    /// The instructor's name, linking to their page by `uuid`.
    public var instructor: PersonRowContent?
    public var instructorNumber: String?
    /// Everyone on the course but the instructor.
    public var people: [PersonRowContent]
    public var notes: String?
  }

  /// The card's rows: the instructor on a row of their own (`splitCourseInstructor`), everyone
  /// else under *People*.
  public static func information(
    _ course: CourseRead, people: [UUID: PersonRead], personLookups: [PersonLookupItem],
    contactLookups: [ContactLookupItem]
  ) -> Information {
    var others = course.people
    let index = others.firstIndex { $0.role == "instructor" }
    let instructorRef = index.map { others.remove(at: $0).person }
    let instructorUUID = instructorRef?.serverUUID
    let instructor = RecordNames.person(
      instructorUUID, people: people, lookups: personLookups
    ).map { PersonRowContent(uuid: instructorUUID, name: $0) }
    return Information(
      diveCenter: RecordNames.contact(course.contactUuid, lookups: contactLookups),
      instructor: instructor,
      instructorNumber: (course.instructorNumber ?? "").isEmpty ? nil : course.instructorNumber,
      people: PersonRowContent.rows(others, people: people),
      notes: course.notes.isEmpty ? nil : course.notes)
  }
}
