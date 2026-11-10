/// The *New Course* dialog's values and rules (`courseSchema`). The instructor has a field of
/// their own and joins the people, first and as the instructor, when the course is sent.
public struct CourseFormValues: Codable, Hashable, Sendable {
  public var name: String
  /// Nil until the diver picks one: a course need not name an agency.
  public var agency: String?
  /// The agency's name, only alongside `other`.
  public var agencyOther: String
  public var status: String
  public var startDate: CalendarDate?
  public var endDate: CalendarDate?
  public var instructor: RecordRef?
  public var instructorNumber: String
  /// The dive centre, school or club that ran it.
  public var contact: RecordRef?
  /// Everyone on the course but the instructor.
  public var people: [PersonReference]
  public var notes: String

  public init(
    name: String = "", agency: String? = nil, agencyOther: String = "",
    status: String = FormVocabulary.defaultCourseStatus, startDate: CalendarDate? = nil,
    endDate: CalendarDate? = nil, instructor: RecordRef? = nil, instructorNumber: String = "",
    contact: RecordRef? = nil, people: [PersonReference] = [], notes: String = ""
  ) {
    self.name = name
    self.agency = agency
    self.agencyOther = agencyOther
    self.status = status
    self.startDate = startDate
    self.endDate = endDate
    self.instructor = instructor
    self.instructorNumber = instructorNumber
    self.contact = contact
    self.people = people
    self.notes = notes
  }

  /// Makes `person` the instructor, taking them off the list below where they would be named
  /// twice.
  public mutating func pickInstructor(_ person: RecordRef?) {
    instructor = person
    if let person { people.removeAll { $0.person == person } }
  }

  /// Moves the start, taking the end with it where the two would run backwards.
  public mutating func pickStartDate(_ day: CalendarDate?) {
    startDate = day
    endDate = RecordFormRules.rangeEnd(endDate, after: day)
  }

  public var issues: [FormIssue] {
    var list = FormIssueList()
    list.add("name", FormText.requiredName(name, "Course name", max: 255))
    list.add("agency_other", FormText.length(agencyOther, "Agency name", max: 64))
    list.add(
      "instructor_number", FormText.length(instructorNumber, "Instructor number", max: 64))
    list.add("notes", FormText.length(notes, "Notes", max: DiveFormBounds.notesMax))
    if agency == "other" && agencyOther.trimmedOfWhitespace.isEmpty {
      list.add("agency_other", "Tell us which agency ran this course")
    }
    if let startDate, let endDate, endDate < startDate {
      list.add("end_date", "End date must be on or after start date")
    }
    return list.issues
  }

  /// `POST /course`'s body: the agency's name only with `other`, the instructor first among the
  /// people (`joinCourseInstructor`), a blank box left out.
  public func toCreate() throws(FormInvalid) -> CourseCreate {
    if !issues.isEmpty { throw FormInvalid(issues: issues) }
    return written
  }

  private var written: CourseCreate {
    let others = people.filter { $0.person != instructor }
    let joined = instructor.map { [PersonReference(person: $0, role: "instructor")] } ?? []
    return CourseCreate(
      name: name.trimmedOfWhitespace, agency: agency,
      agencyOther: agency == "other" && !agencyOther.isEmpty ? agencyOther : nil, status: status,
      startDate: startDate, endDate: endDate,
      instructorNumber: instructorNumber.isEmpty ? nil : instructorNumber, notes: notes,
      contact: contact, people: joined + others)
  }
}

extension CourseFormValues {
  /// The form an edit opens on, the instructor taken out of the people into their own field
  /// (`splitCourseInstructor`).
  public init(editing course: CourseRead) {
    var people = course.people
    let index = people.firstIndex { $0.role == "instructor" }
    let instructor = index.map { people.remove(at: $0).person }
    self.init(
      name: course.name, agency: course.agency, agencyOther: course.agencyOther ?? "",
      status: course.status, startDate: course.startDate, endDate: course.endDate,
      instructor: instructor, instructorNumber: course.instructorNumber ?? "",
      contact: course.contactUuid.map(RecordRef.server), people: people, notes: course.notes)
  }

  /// `PATCH /course/{uuid}`'s body: what differs from the values the form opened on. The
  /// people go whole, the instructor first, when any of them changed.
  public func diff(from baseline: CourseFormValues) throws(FormInvalid) -> CourseUpdate {
    let now = try toCreate()
    let before = baseline.written
    var update = CourseUpdate()
    if now.name != before.name { update.name = now.name }
    if now.status != before.status { update.status = now.status }
    if now.notes != before.notes { update.notes = now.notes }
    if now.people != before.people { update.people = now.people }
    update.agency = .change(from: before.agency, to: now.agency)
    update.agencyOther = .change(from: before.agencyOther, to: now.agencyOther)
    update.startDate = .change(from: before.startDate, to: now.startDate)
    update.endDate = .change(from: before.endDate, to: now.endDate)
    update.instructorNumber = .change(from: before.instructorNumber, to: now.instructorNumber)
    update.contact = .change(from: before.contact, to: now.contact)
    return update
  }

  /// These values with a queued update laid over.
  public func applying(_ update: CourseUpdate) -> CourseFormValues {
    var next = self
    if let name = update.name { next.name = name }
    if let status = update.status { next.status = status }
    if let notes = update.notes { next.notes = notes }
    if var people = update.people {
      next.instructor = nil
      if let first = people.first, first.role == "instructor" {
        next.instructor = first.person
        people.removeFirst()
      }
      next.people = people
    }
    next.agency = update.agency.applied(to: agency)
    next.agencyOther = update.agencyOther.applied(to: agencyOther) ?? ""
    next.startDate = update.startDate.applied(to: startDate)
    next.endDate = update.endDate.applied(to: endDate)
    next.instructorNumber = update.instructorNumber.applied(to: instructorNumber) ?? ""
    next.contact = update.contact.applied(to: contact)
    return next
  }
}

extension CourseFormValues: RewritesLocalRefs {
  public mutating func rewriteRefs(_ rewrite: (RecordRef) -> RecordRef?) {
    instructor.rewrite(rewrite)
    contact.rewrite(rewrite)
    people.rewritePeople(rewrite)
  }
}
