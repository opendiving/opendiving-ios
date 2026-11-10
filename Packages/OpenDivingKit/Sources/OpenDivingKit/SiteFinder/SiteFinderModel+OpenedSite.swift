import Foundation

extension SiteFinderModel {
  /// A site the sites map's panel shows: which one, its name, mark and location once anything has
  /// said them, and whether its pin has been put at the middle of the map.
  public struct OpenedSite: Hashable, Sendable {
    public let uuid: UUID
    public var name: String?
    public var mark: DiveSiteMark?
    /// The place the site is in, `Dahab, Egypt`.
    public var location: String?
    /// The camera has been moved to the site; until then its page's read of where it is moves it.
    var isPlaced: Bool
  }
}
