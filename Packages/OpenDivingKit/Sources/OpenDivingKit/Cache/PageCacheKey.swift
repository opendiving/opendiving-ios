/// Where a ``PagedList`` keeps the pages it has shown, per account, and what else a page
/// tells the cache.
public struct PageCacheKey<Item: Codable & Sendable>: Sendable {
  public let name: String
  /// The highest known dive number a first page sets, for the dives list alone.
  let highestDiveNumber: (@Sendable ([Item]) -> Int?)?

  /// A list of its own name, which no other list in the app uses.
  public init(_ name: String) {
    self.name = name
    highestDiveNumber = nil
  }

  init(_ name: String, highestDiveNumber: @escaping @Sendable ([Item]) -> Int?) {
    self.name = name
    self.highestDiveNumber = highestDiveNumber
  }
}

extension PageCacheKey where Item == DiveListItem {
  /// The Dives tab. Its first row is the newest-dated dive, whose number is the highest the
  /// phone knows.
  public static var dives: Self { Self("dives") { $0.first?.diveNumber } }
}

extension PageCacheKey where Item == TripRead {
  /// The Trips tab.
  public static var trips: Self { Self("trips") }
}

extension PageCacheKey where Item == DiveSiteRead {
  /// The Sites tab.
  public static var diveSites: Self { Self("dive-sites") }
}
