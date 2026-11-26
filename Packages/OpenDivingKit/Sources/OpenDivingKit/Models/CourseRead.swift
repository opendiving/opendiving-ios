import Foundation

/// A training course. Its instructor is a person in `people`.
public struct CourseRead: Codable, Hashable, Sendable, Identifiable {
  public var id: UUID { uuid }

  public let uuid: UUID
  public let name: String
  /// An agency key, as the API sent it; `other` names it in `agencyOther`.
  public let agency: String?
  public let agencyOther: String?
  /// A status key, as the API sent it.
  public let status: String
  public let startDate: CalendarDate?
  public let endDate: CalendarDate?
  public let instructorNumber: String?
  public let notes: String
  /// Its online materials and the like, in the diver's order.
  public let links: [WebLink]
  public let userUuid: UUID
  public let contactUuid: UUID?
  public let people: [PersonReference]
  public let createdAt: DiveTimestamp

  public init(from decoder: any Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    uuid = try c.decode(UUID.self, forKey: .uuid)
    name = try c.decode(String.self, forKey: .name)
    agency = try c.decodeIfPresent(String.self, forKey: .agency)
    agencyOther = try c.decodeIfPresent(String.self, forKey: .agencyOther)
    status = try c.decode(String.self, forKey: .status)
    startDate = try c.decodeIfPresent(CalendarDate.self, forKey: .startDate)
    endDate = try c.decodeIfPresent(CalendarDate.self, forKey: .endDate)
    instructorNumber = try c.decodeIfPresent(String.self, forKey: .instructorNumber)
    notes = try c.decode(String.self, forKey: .notes)
    links = try c.decodeLinks(forKey: .links)
    userUuid = try c.decode(UUID.self, forKey: .userUuid)
    contactUuid = try c.decodeIfPresent(UUID.self, forKey: .contactUuid)
    people = try c.decode([PersonReference].self, forKey: .people)
    createdAt = try c.decode(DiveTimestamp.self, forKey: .createdAt)
  }
}
