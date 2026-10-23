import Foundation

/// One leg of a trip. A trip has no span of its own; it is derived from its parts.
public struct TripPartRead: Codable, Hashable, Sendable {
  public let startDate: CalendarDate?
  public let endDate: CalendarDate?
  public let location: LocationRead?
  public let accommodationUuid: UUID?
  /// Dives on no trip whose day this part covers.
  public let candidateCount: Int
}
