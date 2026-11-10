import Foundation

/// A servicing rule, as `GET /gear-service-schedules` lists it: *a full service every 12 months
/// or every 100 dives, whichever comes first*.
public struct GearServiceScheduleRead: Codable, Hashable, Sendable, Identifiable, GearServiceDue {
  public var id: UUID { uuid }

  public let uuid: UUID
  /// A service-kind key, read as the string the API sent.
  public let kind: String
  /// The day the first due date is measured from, until a service is logged against it.
  public let startsOn: CalendarDate
  public let label: String?
  public let intervalMonths: Int?
  public let intervalDives: Int?
  public let intervalHours: Int?
  public let userUuid: UUID
  public let gearItemUuid: UUID
  /// False while paused.
  public let isActive: Bool
  public let diveCountAtStart: Int
  /// Seconds.
  public let diveTimeAtStart: Int
  public let lastServiceOn: CalendarDate?
  public let nextDueOn: CalendarDate?
  /// A lifetime dive count, not a count remaining.
  public let nextDueAtDiveCount: Int?
  /// A lifetime dive time in seconds, not a time remaining.
  public let nextDueAtDiveTime: Int?
  public let createdAt: DiveTimestamp
}
