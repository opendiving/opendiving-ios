import Foundation

/// One servicing that was done, as `GET /gear-service-records` lists it. It outlives the rule
/// it satisfied.
public struct GearServiceRecordRead: Codable, Hashable, Sendable, Identifiable {
  public var id: UUID { uuid }

  public let uuid: UUID
  /// A service-kind key, read as the string the API sent.
  public let kind: String
  public let servicedOn: CalendarDate
  public let label: String?
  /// Who did the work, a technician or *self*; the shop is ``contactUuid``.
  public let performedBy: String?
  public let notes: String
  public let userUuid: UUID
  public let gearItemUuid: UUID
  public let gearServiceScheduleUuid: UUID?
  /// The shop, a contact.
  public let contactUuid: UUID?
  public let diveCountAtService: Int
  /// Seconds.
  public let diveTimeAtService: Int
  public let createdAt: DiveTimestamp
}
