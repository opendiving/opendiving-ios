import Foundation

/// Where a ``PagedList`` keeps the pages it has shown, per account, and what else a page
/// tells the cache.
public struct PageCacheKey<Item: Codable & Sendable>: Sendable {
  public let name: String
  /// The highest known dive number a first page sets, for the dives list alone.
  let highestDiveNumber: (@Sendable ([Item]) -> Int?)?
  /// The record a row shows, for a list a queued delete takes rows out of.
  let record: (@Sendable (Item) -> UUID)?

  /// A list of its own name, which no other list in the app uses.
  public init(_ name: String) {
    self.name = name
    highestDiveNumber = nil
    record = nil
  }

  init(
    _ name: String, highestDiveNumber: (@Sendable ([Item]) -> Int?)? = nil,
    record: @escaping @Sendable (Item) -> UUID
  ) {
    self.name = name
    self.highestDiveNumber = highestDiveNumber
    self.record = record
  }
}

extension PageCacheKey where Item == DiveListItem {
  /// The Dives tab. Its first row is the newest-dated dive, whose number is the highest the
  /// phone knows.
  public static var dives: Self {
    Self("dives", highestDiveNumber: { $0.first?.diveNumber }, record: \.id)
  }
}

extension PageCacheKey where Item == TripRead {
  /// The Trips tab.
  public static var trips: Self { Self("trips", record: \.uuid) }
}

extension PageCacheKey where Item == DiveListItem {
  /// The dives on one site's page, kept and dropped with the site's own copy.
  static func siteDives(_ site: UUID) -> Self {
    Self(siteDivesPrefix + site.uuidString.lowercased(), record: \.id)
  }

  /// The dives on one trip's page, kept and dropped with the trip's own copy.
  static func tripDives(_ trip: UUID) -> Self {
    Self(tripDivesPrefix + trip.uuidString.lowercased(), record: \.id)
  }

  static var siteDivesPrefix: String { "site-dives-" }
  static var tripDivesPrefix: String { "trip-dives-" }
}

extension PageCacheKey where Item == DiveSiteSearchRow {
  /// The Sites tab's untyped list, *Your sites*' or the sites nearest the camera. A place names
  /// no record, so no delete takes it out.
  static func siteFinder(yours: Bool) -> Self {
    let noRecord = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
    return Self(yours ? "site-finder-yours" : "site-finder-nearby") { row in
      guard case .site(let item) = row, let uuid = item.ref.serverUUID else { return noRecord }
      return uuid
    }
  }
}
