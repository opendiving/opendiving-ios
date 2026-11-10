/// `POST /certification`'s body, `CertificationCreate`. `agencyOther` names the agency when
/// `agency` is `other`, and only then. Card images go after it, a side at a time.
public struct CertificationCreate: Codable, Hashable, Sendable {
  /// An agency key; a certification always names one.
  public var agency: String
  public var agencyOther: String?
  public var name: String
  public var certificationNumber: String?
  public var certifiedOn: CalendarDate?
  public var expiresOn: CalendarDate?
  public var instructorNumber: String?
  public var notes: String
  /// The course the card came out of.
  public var course: RecordRef?
  /// The dive centre that ran it.
  public var contact: RecordRef?
  /// The person who signed it.
  public var instructor: RecordRef?

  enum CodingKeys: String, CodingKey {
    case agency, agencyOther, name, certificationNumber, certifiedOn, expiresOn,
      instructorNumber, notes
    case course = "courseUuid"
    case contact = "contactUuid"
    case instructor = "instructorUuid"
  }

  public init(
    agency: String, agencyOther: String? = nil, name: String, certificationNumber: String? = nil,
    certifiedOn: CalendarDate? = nil, expiresOn: CalendarDate? = nil,
    instructorNumber: String? = nil, notes: String = "", course: RecordRef? = nil,
    contact: RecordRef? = nil, instructor: RecordRef? = nil
  ) {
    self.agency = agency
    self.agencyOther = agencyOther
    self.name = name
    self.certificationNumber = certificationNumber
    self.certifiedOn = certifiedOn
    self.expiresOn = expiresOn
    self.instructorNumber = instructorNumber
    self.notes = notes
    self.course = course
    self.contact = contact
    self.instructor = instructor
  }
}

extension CertificationCreate: RewritesLocalRefs {
  public mutating func rewriteRefs(_ rewrite: (RecordRef) -> RecordRef?) {
    course.rewrite(rewrite)
    contact.rewrite(rewrite)
    instructor.rewrite(rewrite)
  }
}

/// `PATCH /certification/{uuid}`'s body, `CertificationUpdateRequest`: only what is set is sent.
/// The agency, the name and the notes cannot be cleared; a null course, contact or instructor
/// unlinks it.
public struct CertificationUpdate: Codable, Hashable, Sendable {
  public var agency: String?
  public var agencyOther: Patch<String>
  public var name: String?
  public var certificationNumber: Patch<String>
  public var certifiedOn: Patch<CalendarDate>
  public var expiresOn: Patch<CalendarDate>
  public var instructorNumber: Patch<String>
  public var notes: String?
  public var course: Patch<RecordRef>
  public var contact: Patch<RecordRef>
  public var instructor: Patch<RecordRef>

  enum CodingKeys: String, CodingKey {
    case agency, agencyOther, name, certificationNumber, certifiedOn, expiresOn,
      instructorNumber, notes
    case course = "courseUuid"
    case contact = "contactUuid"
    case instructor = "instructorUuid"
  }

  /// An update that changes nothing; set what changed.
  public init() {
    agencyOther = .absent
    certificationNumber = .absent
    certifiedOn = .absent
    expiresOn = .absent
    instructorNumber = .absent
    course = .absent
    contact = .absent
    instructor = .absent
  }

  /// Whether sending it would change nothing.
  public var isEmpty: Bool { self == CertificationUpdate() }
}

extension CertificationUpdate: RewritesLocalRefs {
  public mutating func rewriteRefs(_ rewrite: (RecordRef) -> RecordRef?) {
    course.rewrite(rewrite)
    contact.rewrite(rewrite)
    instructor.rewrite(rewrite)
  }
}
