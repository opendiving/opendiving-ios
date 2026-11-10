/// `PATCH /course/{uuid}`'s body, `CourseUpdateRequest`: only what is set is sent. The name, the
/// status and the notes cannot be cleared; `agencyOther` goes with `agency` `other` alone, and
/// the people replace the course's whole list, the instructor first.
public struct CourseUpdate: Codable, Hashable, Sendable {
  public var name: String?
  public var agency: Patch<String>
  public var agencyOther: Patch<String>
  public var status: String?
  public var startDate: Patch<CalendarDate>
  public var endDate: Patch<CalendarDate>
  public var instructorNumber: Patch<String>
  public var notes: String?
  /// The dive centre, school or club that ran it.
  public var contact: Patch<RecordRef>
  public var people: [PersonReference]?

  enum CodingKeys: String, CodingKey {
    case name, agency, agencyOther, status, startDate, endDate, instructorNumber, notes, people
    case contact = "contactUuid"
  }

  /// An update that changes nothing; set what changed.
  public init() {
    agency = .absent
    agencyOther = .absent
    startDate = .absent
    endDate = .absent
    instructorNumber = .absent
    contact = .absent
  }

  /// Whether sending it would change nothing.
  public var isEmpty: Bool { self == CourseUpdate() }
}

extension CourseUpdate: RewritesLocalRefs {
  public mutating func rewriteRefs(_ rewrite: (RecordRef) -> RecordRef?) {
    contact.rewrite(rewrite)
    if var list = people {
      list.rewritePeople(rewrite)
      people = list
    }
  }
}
