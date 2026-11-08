import Foundation

/// A site the map shows, as touching its point opens it: enough to name it, mark a Commons
/// record and credit it, and to put it on a dive.
public struct SiteFinderPoint: Hashable, Sendable, Identifiable {
  public var id: UUID { uuid }
  public let uuid: UUID
  public let name: String
  public let latitude: Double
  public let longitude: Double
  public let isCommons: Bool
  /// On the diver's list.
  public let saved: Bool
  public let credit: String?

  /// The point as a picker's row, which a dive form keeps to name it.
  public var lookupItem: DiveSiteLookupItem {
    DiveSiteLookupItem(
      ref: .server(uuid), name: name, latitude: latitude, longitude: longitude,
      owner: isCommons ? DiveSiteOwner.commons : DiveSiteOwner.account, saved: saved,
      attribution: credit)
  }
}
