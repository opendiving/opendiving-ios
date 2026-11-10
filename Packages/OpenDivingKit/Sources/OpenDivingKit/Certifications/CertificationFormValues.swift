/// The certification dialog's values and rules (`certificationSchema`), and what the form last
/// put in the fields a course fills itself, so a pick replaces only what nobody has typed over.
public struct CertificationFormValues: Hashable, Sendable {
  /// The training the card came out of.
  public var course: RecordRef?
  /// The level as printed on the card.
  public var name: String
  /// An agency key; a card always names one.
  public var agency: String
  /// The agency's name, only alongside `other`.
  public var agencyOther: String
  public var certificationNumber: String
  public var certifiedOn: CalendarDate?
  public var expiresOn: CalendarDate?
  /// The dive centre that ran it.
  public var contact: RecordRef?
  /// The person who signed it.
  public var instructor: RecordRef?
  public var instructorNumber: String
  public var notes: String
  /// The fields a course fills, as the form opened with them or as the last course wrote them.
  public private(set) var autofilled: Filled

  /// The six fields a course fills, as the form holds them.
  public struct Filled: Hashable, Sendable {
    public var name: String
    public var agency: String
    public var agencyOther: String
    public var contact: RecordRef?
    public var instructor: RecordRef?
    public var instructorNumber: String
  }

  /// What the form opens on, PADI being the agency most divers hold a card from
  /// (`DEFAULT_CERTIFICATION_AGENCY`).
  public static let defaultAgency = "padi"

  public init(
    course: RecordRef? = nil, name: String = "", agency: String = Self.defaultAgency,
    agencyOther: String = "", certificationNumber: String = "", certifiedOn: CalendarDate? = nil,
    expiresOn: CalendarDate? = nil, contact: RecordRef? = nil, instructor: RecordRef? = nil,
    instructorNumber: String = "", notes: String = ""
  ) {
    self.course = course
    self.name = name
    self.agency = agency
    self.agencyOther = agencyOther
    self.certificationNumber = certificationNumber
    self.certifiedOn = certifiedOn
    self.expiresOn = expiresOn
    self.contact = contact
    self.instructor = instructor
    self.instructorNumber = instructorNumber
    self.notes = notes
    autofilled = Filled(
      name: name, agency: agency, agencyOther: agencyOther, contact: contact,
      instructor: instructor, instructorNumber: instructorNumber)
  }

  /// A new card for `course`, opened already filled from it. A course naming no agency leaves the
  /// form's own default, the one path that could otherwise open with a required field unset.
  public init(for course: CertificationCourseFill, ref: RecordRef) {
    self.init(course: ref)
    fill(from: course)
    autofilled = filled
  }

  /// Moves the certified date, taking the expiry with it where the two would run backwards.
  public mutating func pickCertifiedOn(_ day: CalendarDate?) {
    certifiedOn = day
    expiresOn = RecordFormRules.rangeEnd(expiresOn, after: day)
  }

  /// Copies a course's fields across, each only where it still holds what the form itself put
  /// there. The agency pair goes together, and only when the course names an agency: the API
  /// refuses a named agency with a name of its own, and `other` without one. The notes are never
  /// filled, a course's describing the training rather than the card.
  public mutating func fill(from course: CertificationCourseFill) {
    if name == autofilled.name {
      name = course.name
      autofilled.name = course.name
    }
    if let courseAgency = course.agency {
      if agency == autofilled.agency {
        agency = courseAgency
        autofilled.agency = courseAgency
      }
      if agencyOther == autofilled.agencyOther {
        agencyOther = course.agencyOther
        autofilled.agencyOther = course.agencyOther
      }
    }
    if contact == autofilled.contact {
      contact = course.contact
      autofilled.contact = course.contact
    }
    if instructor == autofilled.instructor {
      instructor = course.instructor
      autofilled.instructor = course.instructor
    }
    if let number = course.instructorNumber, instructorNumber == autofilled.instructorNumber {
      instructorNumber = number
      autofilled.instructorNumber = number
    }
  }

  private var filled: Filled {
    Filled(
      name: name, agency: agency, agencyOther: agencyOther, contact: contact,
      instructor: instructor, instructorNumber: instructorNumber)
  }

  public var issues: [FormIssue] {
    var list = FormIssueList()
    list.add("agency_other", FormText.length(agencyOther, "Agency name", max: 64))
    list.add("name", FormText.requiredName(name, "Certification name", max: 255))
    list.add(
      "certification_number",
      FormText.length(certificationNumber, "Certification number", max: 64))
    list.add(
      "instructor_number", FormText.length(instructorNumber, "Instructor number", max: 64))
    list.add("notes", FormText.length(notes, "Notes", max: DiveFormBounds.notesMax))
    if agency == "other" && agencyOther.trimmedOfWhitespace.isEmpty {
      list.add("agency_other", "Tell us which agency issued this")
    }
    if let certifiedOn, let expiresOn, expiresOn < certifiedOn {
      list.add("expires_on", "Expiry date cannot be before the certification date")
    }
    return list.issues
  }

  /// `POST /certification`'s body: the agency's name only with `other`, the name trimmed, a
  /// blank box left out.
  public func toCreate() throws(FormInvalid) -> CertificationCreate {
    if !issues.isEmpty { throw FormInvalid(issues: issues) }
    return written
  }

  private var written: CertificationCreate {
    CertificationCreate(
      agency: agency, agencyOther: agency == "other" && !agencyOther.isEmpty ? agencyOther : nil,
      name: name.trimmedOfWhitespace,
      certificationNumber: certificationNumber.isEmpty ? nil : certificationNumber,
      certifiedOn: certifiedOn, expiresOn: expiresOn,
      instructorNumber: instructorNumber.isEmpty ? nil : instructorNumber, notes: notes,
      course: course, contact: contact, instructor: instructor)
  }
}

extension CertificationFormValues {
  /// The form an edit opens on, the card as stored.
  public init(editing certification: CertificationRead) {
    self.init(
      course: certification.courseUuid.map(RecordRef.server), name: certification.name,
      agency: certification.agency, agencyOther: certification.agencyOther ?? "",
      certificationNumber: certification.certificationNumber ?? "",
      certifiedOn: certification.certifiedOn, expiresOn: certification.expiresOn,
      contact: certification.contactUuid.map(RecordRef.server),
      instructor: certification.instructorUuid.map(RecordRef.server),
      instructorNumber: certification.instructorNumber ?? "", notes: certification.notes)
  }

  /// `PATCH /certification/{uuid}`'s body: what differs from the values the form opened on.
  public func diff(from baseline: CertificationFormValues) throws(FormInvalid)
    -> CertificationUpdate
  {
    let now = try toCreate()
    let before = baseline.written
    var update = CertificationUpdate()
    if now.agency != before.agency { update.agency = now.agency }
    if now.name != before.name { update.name = now.name }
    if now.notes != before.notes { update.notes = now.notes }
    update.agencyOther = .change(from: before.agencyOther, to: now.agencyOther)
    update.certificationNumber = .change(
      from: before.certificationNumber, to: now.certificationNumber)
    update.certifiedOn = .change(from: before.certifiedOn, to: now.certifiedOn)
    update.expiresOn = .change(from: before.expiresOn, to: now.expiresOn)
    update.instructorNumber = .change(from: before.instructorNumber, to: now.instructorNumber)
    update.course = .change(from: before.course, to: now.course)
    update.contact = .change(from: before.contact, to: now.contact)
    update.instructor = .change(from: before.instructor, to: now.instructor)
    return update
  }

  /// These values with a queued update laid over.
  public func applying(_ update: CertificationUpdate) -> CertificationFormValues {
    var next = self
    if let agency = update.agency { next.agency = agency }
    if let name = update.name { next.name = name }
    if let notes = update.notes { next.notes = notes }
    next.agencyOther = update.agencyOther.applied(to: agencyOther) ?? ""
    next.certificationNumber =
      update.certificationNumber.applied(to: certificationNumber) ?? ""
    next.certifiedOn = update.certifiedOn.applied(to: certifiedOn)
    next.expiresOn = update.expiresOn.applied(to: expiresOn)
    next.instructorNumber = update.instructorNumber.applied(to: instructorNumber) ?? ""
    next.course = update.course.applied(to: course)
    next.contact = update.contact.applied(to: contact)
    next.instructor = update.instructor.applied(to: instructor)
    next.autofilled = next.filled
    return next
  }
}

extension CertificationFormValues: RecordEditValues {
  public func operation() throws(FormInvalid) -> OutboxOperation {
    .createCertification(try toCreate())
  }

  /// What a refused create sent, which opens as the form's own: a course picked after it fills
  /// only what the diver has not changed since.
  public init?(reopening operation: OutboxOperation) {
    guard case .createCertification(let body) = operation else { return nil }
    self.init(
      course: body.course, name: body.name, agency: body.agency,
      agencyOther: body.agencyOther ?? "", certificationNumber: body.certificationNumber ?? "",
      certifiedOn: body.certifiedOn, expiresOn: body.expiresOn, contact: body.contact,
      instructor: body.instructor, instructorNumber: body.instructorNumber ?? "",
      notes: body.notes)
  }

  public func update(of ref: RecordRef, from baseline: CertificationFormValues) throws(FormInvalid)
    -> OutboxOperation?
  {
    let update = try diff(from: baseline)
    return update.isEmpty ? nil : .updateCertification(ref, update)
  }

  public func applying(_ operation: OutboxOperation) -> CertificationFormValues {
    if case .updateCertification(_, let update) = operation { applying(update) } else { self }
  }

  public static func delete(_ ref: RecordRef) -> OutboxOperation { .deleteCertification(ref) }
}

extension CertificationFormValues: RewritesLocalRefs {
  public mutating func rewriteRefs(_ rewrite: (RecordRef) -> RecordRef?) {
    course.rewrite(rewrite)
    contact.rewrite(rewrite)
    instructor.rewrite(rewrite)
    autofilled.contact.rewrite(rewrite)
    autofilled.instructor.rewrite(rewrite)
  }
}
