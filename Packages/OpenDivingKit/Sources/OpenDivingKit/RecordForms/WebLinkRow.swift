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
  /// host `urlsplit` splits, holding no character of the format's whitespace class, at most 512
  /// characters as Python counts them.
  static func isAddress(_ url: String) -> Bool {
    let scalars = Array(url.unicodeScalars)
    guard scalars.count <= 512, !scalars.contains(where: isLinkWhitespace) else { return false }
    let schemeLength: Int
    if hasPrefix(scalars, "https://") {
      schemeLength = 8
    } else if hasPrefix(scalars, "http://") {
      schemeLength = 7
    } else {
      return false
    }
    let netloc = Array(
      scalars.dropFirst(schemeLength).prefix { !"/?#".unicodeScalars.contains($0) })
    return !netloc.isEmpty && isSplittable(netloc)
  }

  private static func hasPrefix(_ scalars: [Unicode.Scalar], _ prefix: String) -> Bool {
    let head = scalars.prefix(prefix.unicodeScalars.count)
    return head.count == prefix.unicodeScalars.count
      && zip(head, prefix.unicodeScalars).allSatisfy {
        $0.isASCII && $0.properties.lowercaseMapping == String($1)
      }
  }

  /// `urlsplit`'s own refusals of a host part, each a 422 at the API: unbalanced brackets, a
  /// bracketed host that is not IPv6 or IPvFuture, and a non-ASCII host NFKC turns into a URL
  /// delimiter.
  private static func isSplittable(_ netloc: [Unicode.Scalar]) -> Bool {
    let open = netloc.contains("[")
    guard open == netloc.contains("]") else { return false }
    if open, !isBracketedHostAndPort(netloc) { return false }
    guard !netloc.allSatisfy(\.isASCII) else { return true }
    var bare = String.UnicodeScalarView()
    bare.append(contentsOf: netloc.filter { !"@:#?".unicodeScalars.contains($0) })
    let text = String(bare)
    let normalized = text.precomposedStringWithCompatibilityMapping
    return normalized.unicodeScalars.elementsEqual(text.unicodeScalars)
      || !normalized.unicodeScalars.contains { "/?#@:".unicodeScalars.contains($0) }
  }

  /// `_check_bracketed_netloc`: the host after the last `@`, bracketed from its first character
  /// with nothing but a port after the bracket.
  private static func isBracketedHostAndPort(_ netloc: [Unicode.Scalar]) -> Bool {
    let hostAndPort = netloc.lastIndex(of: "@").map { Array(netloc[($0 + 1)...]) } ?? netloc
    let host: [Unicode.Scalar]
    if let bracket = hostAndPort.firstIndex(of: "[") {
      guard bracket == 0 else { return false }
      let bracketed = hostAndPort.dropFirst()
      let end = bracketed.firstIndex(of: "]")
      host = Array(bracketed[..<(end ?? bracketed.endIndex)])
      let port = end.map { bracketed[($0 + 1)...] } ?? []
      if let first = port.first, first != ":" { return false }
    } else {
      host = Array(hostAndPort.prefix { $0 != ":" })
    }
    if host.first == "v" || host.first == "V" { return isIPvFuture(host) }
    return isIPv6(host)
  }

  /// `[vV][a-fA-F0-9]+\..+`, whole.
  private static func isIPvFuture(_ host: [Unicode.Scalar]) -> Bool {
    let rest = host.dropFirst()
    guard let dot = rest.firstIndex(of: ".") else { return false }
    let digits = rest[..<dot]
    return !digits.isEmpty && digits.allSatisfy(isHexDigit) && dot + 1 < host.endIndex
  }

  /// Python's `ipaddress.IPv6Address`, scope id included, which is what `urlsplit` asks of a
  /// bracketed host (an IPv4 address it refuses there).
  private static func isIPv6(_ host: [Unicode.Scalar]) -> Bool {
    var address = host
    if let percent = address.firstIndex(of: "%") {
      let scope = address[(percent + 1)...]
      guard !scope.isEmpty, !scope.contains("%") else { return false }
      address = Array(address[..<percent])
    }
    var parts = address.split(separator: ":", omittingEmptySubsequences: false).map(Array.init)
    guard parts.count >= 3 else { return false }
    if parts[parts.count - 1].contains(".") {
      guard isIPv4(parts[parts.count - 1]) else { return false }
      parts.removeLast()
      parts += [["0"], ["0"]]
    }
    guard parts.count <= 9 else { return false }
    var skip: Int?
    for index in 1..<(parts.count - 1) where parts[index].isEmpty {
      guard skip == nil else { return false }
      skip = index
    }
    let hextets: [[Unicode.Scalar]]
    if let skip {
      var high = skip
      var low = parts.count - skip - 1
      if parts[0].isEmpty {
        high -= 1
        guard high == 0 else { return false }
      }
      if parts[parts.count - 1].isEmpty {
        low -= 1
        guard low == 0 else { return false }
      }
      guard 8 - (high + low) >= 1 else { return false }
      hextets = Array(parts.prefix(high) + parts.suffix(low))
    } else {
      guard parts.count == 8, !parts[0].isEmpty, !parts[7].isEmpty else { return false }
      hextets = parts
    }
    return hextets.allSatisfy { (1...4).contains($0.count) && $0.allSatisfy(isHexDigit) }
  }

  private static func isIPv4(_ address: [Unicode.Scalar]) -> Bool {
    let octets = address.split(separator: ".", omittingEmptySubsequences: false)
    return octets.count == 4
      && octets.allSatisfy { octet in
        (1...3).contains(octet.count) && octet.allSatisfy { ("0"..."9").contains($0) }
          && (octet.count == 1 || octet.first != "0")
          && Int(String(String.UnicodeScalarView(octet)))! <= 255
      }
  }

  private static func isHexDigit(_ scalar: Unicode.Scalar) -> Bool {
    ("0"..."9").contains(scalar) || ("a"..."f").contains(scalar) || ("A"..."F").contains(scalar)
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
