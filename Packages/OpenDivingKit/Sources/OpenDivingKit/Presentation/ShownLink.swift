import Foundation

/// One of a record's links as a page lists it: its label, or its address without the scheme
/// where it has none, opening the address.
public struct ShownLink: Hashable, Sendable {
  public var text: String
  /// Nil for a stored address that does not parse, which is shown and opens nothing.
  public var url: URL?

  public init(text: String, url: URL?) {
    self.text = text
    self.url = url
  }

  /// A record's links in the diver's order; a link with no address is left out.
  public static func list(_ links: [WebLink]) -> [ShownLink] {
    links.compactMap { link in
      guard !link.url.isEmpty else { return nil }
      let label = link.label.flatMap { $0.trimmedOfWhitespace.isEmpty ? nil : $0 }
      return ShownLink(
        text: label ?? DiveDetailText.linkAddress(link.url), url: URL(string: link.url))
    }
  }
}
