import Foundation

/// One row of a record form's links: an address and a label as typed. Two rows are equal by what
/// they hold; the identity only keeps a row in its place on screen as the rows move.
public struct WebLinkRow: Codable, Hashable, Sendable, Identifiable {
  public let id: UUID
  public var url: String
  public var label: String

  public init(id: UUID = UUID(), url: String = "", label: String = "") {
    self.id = id
    self.url = url
    self.label = label
  }

  public static func == (lhs: WebLinkRow, rhs: WebLinkRow) -> Bool {
    lhs.url == rhs.url && lhs.label == rhs.label
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(url)
    hasher.combine(label)
  }

  /// The rows a form opens on.
  public static func rows(_ links: [WebLink]) -> [WebLinkRow] {
    links.map { WebLinkRow(url: $0.url, label: $0.label ?? "") }
  }

  /// Whether another row fits.
  public static func canAdd(to rows: [WebLinkRow]) -> Bool { rows.count < WebLink.maxLinks }

  /// The list as sent: each address trimmed and a bare host given `https://`, a blank row left
  /// out, a blank label nil, an address named twice kept where it first appears.
  static func written(_ rows: [WebLinkRow]) -> [WebLink] {
    var seen: Set<String> = []
    var links: [WebLink] = []
    for row in rows {
      guard let url = row.sentURL, seen.insert(url).inserted else { continue }
      links.append(WebLink(url: url, label: FormText.trimmedOrNil(row.label)))
    }
    return links
  }

  /// A create's or a diff's list: nil for none, so a body with no links encodes no key for them.
  static func sent(_ rows: [WebLinkRow]) -> [WebLink]? {
    let links = written(rows)
    return links.isEmpty ? nil : links
  }

  /// The sentences under the rows, each judged as it will be sent by the API's own rule, so a
  /// write is never queued to wait refused in the outbox.
  static func check(_ rows: [WebLinkRow], into list: inout FormIssueList) {
    for (index, row) in rows.enumerated() {
      if let url = row.sentURL {
        if !isAddress(url) {
          list.add("links", index: index, member: "url", "Use a web address, e.g. blueocean.com")
        }
      } else if !row.label.trimmedOfWhitespace.isEmpty {
        list.add("links", index: index, member: "url", "Add the address this label is for")
      }
      list.add(
        "links", index: index, member: "label",
        FormText.length(row.label.trimmedOfWhitespace, "Label", max: 120))
    }
    if written(rows).count > WebLink.maxLinks {
      list.add("links", "A record keeps at most \(WebLink.maxLinks) links")
    }
  }

  /// The address as sent (`normalizeWebsite`); nil for a blank box.
  var sentURL: String? {
    guard let trimmed = FormText.trimmedOrNil(url) else { return nil }
    return Self.hasScheme(trimmed) ? trimmed : "https://" + trimmed
  }

  private static func hasScheme(_ text: String) -> Bool {
    guard let colon = text.range(of: "://") else { return false }
    let scheme = text[..<colon.lowerBound]
    guard let first = scheme.first, first.isASCII, first.isLetter else { return false }
    return scheme.allSatisfy { $0.isASCIILetterOrDigit || "+.-".contains($0) }
  }

  /// The API's `check_link_url`: an `http` or `https` address opening on its scheme, with a
  /// host, holding no character of the format's whitespace class, at most 512 long.
  static func isAddress(_ url: String) -> Bool {
    let scalars = Array(url.unicodeScalars)
    guard url.utf16.count <= 512, !scalars.contains(where: isLinkWhitespace) else { return false }
    let lowered = String(String.UnicodeScalarView(scalars.prefix(8))).lowercased()
    let schemeLength =
      lowered.hasPrefix("https://") ? 8 : lowered.hasPrefix("http://") ? 7 : nil
    guard let schemeLength else { return false }
    let host = scalars.dropFirst(schemeLength).prefix { !"/?#".unicodeScalars.contains($0) }
    guard !host.isEmpty else { return false }
    // `urlsplit` refuses a host with one bracket and not the other.
    return host.contains("[") == host.contains("]")
  }

  /// `LINK_WHITESPACE`, by code point: every character ECMA-262's or Python's `\s` matches,
  /// which `CharacterSet.whitespacesAndNewlines` is not.
  private static func isLinkWhitespace(_ scalar: Unicode.Scalar) -> Bool {
    switch scalar.value {
    case 0x0009...0x000D, 0x001C...0x0020, 0x0085, 0x00A0, 0x1680, 0x2000...0x200A, 0x2028,
      0x2029, 0x202F, 0x205F, 0x3000, 0xFEFF:
      true
    default: false
    }
  }
}
