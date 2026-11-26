import Foundation

/// One of a record's links, `Link` on the way in and `LinkRead` on the way out: an address to
/// open and what it is. A contact, a person, a course, a gear item and a trip each keep a list,
/// in the diver's order.
public struct WebLink: Codable, Hashable, Sendable {
  public var url: String
  /// Shown in place of the address; nil is none.
  public var label: String?

  public init(url: String, label: String? = nil) {
    self.url = url
    self.label = label
  }

  /// The most links a record keeps, `LINKS_MAX`.
  public static let maxLinks = 20
}

extension KeyedDecodingContainer {
  /// A record's links, empty where the body has none: a page cached before records carried
  /// links reads as a record with none.
  func decodeLinks(forKey key: Key) throws -> [WebLink] {
    try decodeIfPresent([WebLink].self, forKey: key) ?? []
  }
}
