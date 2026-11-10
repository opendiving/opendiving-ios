import Foundation

/// A servicing rule as a gear item carries it: its due points and nothing derived, since a
/// status depends on the day it is read (``GearServiceDue``).
public struct GearServiceScheduleInfo: Codable, Hashable, Sendable, Identifiable, GearServiceDue {
  public var id: UUID { uuid }

  public let uuid: UUID
  /// A service-kind key, read as the string the API sent.
  public let kind: String
  public let label: String?
  public let intervalMonths: Int?
  public let intervalDives: Int?
  public let intervalHours: Int?
  public let lastServiceOn: CalendarDate?
  public let nextDueOn: CalendarDate?
  public let nextDueAtDiveCount: Int?
  public let nextDueAtDiveTime: Int?
  public let isActive: Bool
}
