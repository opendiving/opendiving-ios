import Foundation

/// A training course. Its instructor is a person in `people`.
public struct CourseRead: Codable, Hashable, Sendable {
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
  public let userUuid: UUID
  public let contactUuid: UUID?
  public let people: [PersonReference]
  public let createdAt: DiveTimestamp
}
