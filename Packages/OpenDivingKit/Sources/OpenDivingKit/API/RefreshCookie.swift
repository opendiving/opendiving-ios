import Foundation

/// Reads the `refresh_token` cookie's value off a response's `Set-Cookie`, which Foundation
/// hands over as one string even when the server sent several, joined with commas — while an
/// `expires` attribute carries a comma of its own. A JWT holds neither a comma nor a
/// semicolon, so the value runs from `refresh_token=` to the first of them. The attributes,
/// `Secure` included, are not honoured: the token is bound to the exact origin it came from.
enum RefreshCookie {
  static let name = "refresh_token"

  /// The value, or nil when the header sets no `refresh_token` or clears it.
  static func value(inSetCookie header: String?) -> String? {
    guard let header else { return nil }
    var searchStart = header.startIndex
    while let range = header.range(of: name + "=", range: searchStart..<header.endIndex) {
      searchStart = range.upperBound
      let before = header[header.startIndex..<range.lowerBound].last { $0 != " " }
      guard before == nil || before == "," || before == ";" else { continue }
      let rest = header[range.upperBound...]
      let end = rest.firstIndex { $0 == ";" || $0 == "," } ?? rest.endIndex
      var value = String(rest[rest.startIndex..<end]).trimmingCharacters(in: .whitespaces)
      if value.hasPrefix("\""), value.hasSuffix("\""), value.count >= 2 {
        value = String(value.dropFirst().dropLast())
      }
      return value.isEmpty ? nil : value
    }
    return nil
  }
}
