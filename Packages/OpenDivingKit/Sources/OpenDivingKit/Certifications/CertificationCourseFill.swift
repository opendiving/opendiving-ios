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

  /// A picker's row, which carries no agency and no number: what the phone has offline for a
  /// course it has never opened.
  public init(_ row: CourseLookupItem) {
    self.init(
      name: row.name, contact: row.contact, instructor: Self.instructor(row.people),
      instructorNumber: nil)
  }

  /// The course's first instructor (`splitCourseInstructor`).
  static func instructor(_ people: [PersonReference]) -> RecordRef? {
    people.first { $0.role == "instructor" }?.person
  }

  /// The course `ref` as the form fills from it: the server's copy, read as the web reads it on
  /// a pick; offline, the copy the phone keeps from its page, the body a course made here waits
  /// with, or else the picker's row. Nil when the phone knows nothing of it.
  @MainActor
  public static func read(
    _ ref: RecordRef, session: Session, outbox: OutboxModel, rows: [CourseLookupItem]
  ) async -> CertificationCourseFill? {
    switch ref {
    case .server(let uuid):
      if let client = try? session.routedClient(), let course = try? await client.course(uuid) {
        return CertificationCourseFill(course)
      }
      if let kept = AccountStores.current(session)?.cache.record(.course, uuid) {
        return CertificationCourseFill(kept.value)
      }
    case .local:
      let queued = outbox.items.lazy.compactMap { item -> CourseCreate? in
        guard item.creates == ref, case .createCourse(let body) = item.operation else {
          return nil
        }
        return body
      }.first
      if let queued { return CertificationCourseFill(queued) }
    }
    return rows.first { $0.ref == ref }.map(CertificationCourseFill.init)
  }
}
