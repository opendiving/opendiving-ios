import Foundation

/// A dive site, with the summary of the diver's own dives there.
public struct DiveSiteRead: Codable, Hashable, Sendable, Identifiable {
  public var id: UUID { uuid }

  public let uuid: UUID
  public let name: String
  public let latitude: Double?
  public let longitude: Double?
  public let notes: String
  public let otherNames: [String]
  public let externalIds: [ExternalIdRead]
  /// Metres.
  public let depthFrom: Double?
  public let depthTo: Double?
  public let waterType: String?
  /// Whole metres above sea level.
  public let altitude: Int?
  public let entryTypes: [String]
  public let tags: [String]
  public let location: LocationRead?
  public let diveCount: Int
  public let lastDivedOn: CalendarDate?
  /// Metres.
  public let maxDiveDepth: Double?
  public let speciesCount: Int
  public let averageRating: Double?
  public let userUuid: UUID
  public let createdAt: DiveTimestamp
}
