import Foundation

/// What picking a course puts in a new certification's form (`courseFieldValues`): its name,
/// its agency, its dive centre, its first instructor — a card is signed by one person — and
/// their number.
public struct CertificationCourseFill: Hashable, Sendable {
  public var name: String
  /// Nil for a course that names no agency, which hands over no agency pair.
  public var agency: String?
  public var agencyOther: String
  public var contact: RecordRef?
  public var instructor: RecordRef?
  /// Nil where the phone does not know it, which leaves the field alone.
  public var instructorNumber: String?

  public init(
    name: String, agency: String? = nil, agencyOther: String = "", contact: RecordRef? = nil,
    instructor: RecordRef? = nil, instructorNumber: String? = ""
  ) {
    self.name = name
    self.agency = agency
    self.agencyOther = agencyOther
    self.contact = contact
    self.instructor = instructor
    self.instructorNumber = instructorNumber
  }

  public init(_ course: CourseRead) {
    self.init(
      name: course.name, agency: course.agency, agencyOther: course.agencyOther ?? "",
      contact: course.contactUuid.map(RecordRef.server),
      instructor: Self.instructor(course.people), instructorNumber: course.instructorNumber ?? "")
  }

  /// A course created on the phone and not yet sent, from the body it waits with.
  public init(_ body: CourseCreate) {
    self.init(
      name: body.name, agency: body.agency, agencyOther: body.agencyOther ?? "",
      contact: body.contact, instructor: Self.instructor(body.people),
      instructorNumber: body.instructorNumber ?? "")
  }

  /// A picker's row, which carries no agency and no number, so a pick leaves both alone.
  public init(_ row: CourseLookupItem) {
    self.init(
      name: row.name, contact: row.contact, instructor: Self.instructor(row.people),
      instructorNumber: nil)
  }

  /// The course's first instructor (`splitCourseInstructor`).
  static func instructor(_ people: [PersonReference]) -> RecordRef? {
    people.first { $0.role == "instructor" }?.person
  }

  /// The course `ref` as a pick fills the form from it, asking the server nothing: a course
  /// made on the phone from the body it waits with, any other from the picker's row. Nil when
  /// the phone holds neither.
  @MainActor
  public static func picked(
    _ ref: RecordRef, outbox: OutboxModel, rows: [CourseLookupItem]
  ) -> CertificationCourseFill? {
    let queued = outbox.items.lazy.compactMap { item -> CourseCreate? in
      guard item.creates == ref, case .createCourse(let body) = item.operation else { return nil }
      return body
    }.first
    if let queued { return CertificationCourseFill(queued) }
    return rows.first { $0.ref == ref }.map(CertificationCourseFill.init)
  }
}
