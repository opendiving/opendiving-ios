import Foundation

extension SiteFinderModel {
  /// A site the sites map's panel shows: which one, its name once anything has said it, whether
  /// it is a Commons record, and whether its pin has been put at the middle of the map.
  public struct OpenedSite: Hashable, Sendable {
    public let uuid: UUID
    public var name: String?
    public var isCommons: Bool
    /// The camera has been moved to the site; until then its page's read of where it is moves it.
    var isPlaced: Bool
  }
}
