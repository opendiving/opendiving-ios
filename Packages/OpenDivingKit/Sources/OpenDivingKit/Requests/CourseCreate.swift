/// `POST /course`'s body, `CourseCreate`. `agencyOther` names the agency when `agency` is
/// `other`, and only then; a nil `status` is the API's default, `completed`.
public struct CourseCreate: Codable, Hashable, Sendable {
  public var name: String
  public var agency: String?
  public var agencyOther: String?
  public var status: String?
  public var startDate: CalendarDate?
  public var endDate: CalendarDate?
  public var instructorNumber: String?
  public var notes: String
  /// The dive centre, school or club that ran it.
  public var contact: RecordRef?
  public var people: [PersonReference]

  enum CodingKeys: String, CodingKey {
    case name, agency, agencyOther, status, startDate, endDate, instructorNumber, notes, people
    case contact = "contactUuid"
  }

  public init(
    name: String, agency: String? = nil, agencyOther: String? = nil, status: String? = nil,
    startDate: CalendarDate? = nil, endDate: CalendarDate? = nil,
    instructorNumber: String? = nil, notes: String = "", contact: RecordRef? = nil,
    people: [PersonReference] = []
  ) {
    self.name = name
    self.agency = agency
    self.agencyOther = agencyOther
    self.status = status
    self.startDate = startDate
    self.endDate = endDate
    self.instructorNumber = instructorNumber
    self.notes = notes
    self.contact = contact
    self.people = people
  }
}

extension CourseCreate: RewritesLocalRefs {
  public mutating func rewriteRefs(_ rewrite: (RecordRef) -> RecordRef?) {
    contact.rewrite(rewrite)
    people.rewritePeople(rewrite)
  }
}
