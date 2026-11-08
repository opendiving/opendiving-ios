import Foundation

/// What the reader's own dives say of a site, as a search row carries it: the figures the site's
/// card shows.
public struct DiveSiteDives: Codable, Hashable, Sendable {
  public let diveCount: Int
  public let lastDivedOn: CalendarDate?
  public let maxDiveDepth: Double?
  public let speciesCount: Int
  public let averageRating: Double?

  public init(
    diveCount: Int = 0, lastDivedOn: CalendarDate? = nil, maxDiveDepth: Double? = nil,
    speciesCount: Int = 0, averageRating: Double? = nil
  ) {
    self.diveCount = diveCount
    self.lastDivedOn = lastDivedOn
    self.maxDiveDepth = maxDiveDepth
    self.speciesCount = speciesCount
    self.averageRating = averageRating
  }
}
