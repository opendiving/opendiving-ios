import Foundation

/// `GET /user/dive-stats`: the logbook's totals.
public struct UserDiveStatsRead: Codable, Hashable, Sendable {
  public let totalDives: Int
  /// Metres.
  public let maxDepth: Double
  /// Seconds in the water, surface time excluded.
  public let totalSubmergedTime: Int
  public let speciesSeen: Int
  public let diveSiteCount: Int
  public let firstDiveOn: CalendarDate?
  public let lastDiveOn: CalendarDate?
  public let userUuid: UUID
  public let createdAt: DiveTimestamp
}
