import Foundation

/// An export as it landed on the phone: one file, alone in a directory of its own, named as
/// the server named it, waiting for the share sheet.
public struct ExportedFile: Hashable, Sendable, Identifiable {
  public let url: URL

  public var id: URL { url }

  /// Removes the file and its directory.
  public func remove() {
    try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
  }

  /// The name a `Content-Disposition` header gives — `filename*` over `filename` — as one path
  /// component, or nil when it gives none that can name a file.
  static func filename(contentDisposition header: String?) -> String? {
    guard let header else { return nil }
    var plain: String?
    var extended: String?
    for parameter in header.split(separator: ";") {
      let pair = parameter.split(separator: "=", maxSplits: 1)
      guard pair.count == 2 else { continue }
      let key = pair[0].trimmingCharacters(in: .whitespaces).lowercased()
      var value = pair[1].trimmingCharacters(in: .whitespaces)
      if key == "filename*" {
        // `UTF-8''name%20here`: the charset, an optional language, then the encoded name.
        let parts = value.split(separator: "'", maxSplits: 2, omittingEmptySubsequences: false)
        if parts.count == 3, parts[0].lowercased() == "utf-8" {
          extended = String(parts[2]).removingPercentEncoding
        }
      } else if key == "filename" {
        if value.count >= 2, value.hasPrefix("\""), value.hasSuffix("\"") {
          value = String(value.dropFirst().dropLast())
        }
        plain = value
      }
    }
    return [extended, plain].lazy.compactMap { $0.flatMap(component) }.first
  }

  /// `name` as a single path component: what follows its last slash, and nothing that walks
  /// out of the directory.
  private static func component(_ name: String) -> String? {
    let last = name.split(whereSeparator: { $0 == "/" || $0 == "\\" }).last.map(String.init)
    guard let last, last != ".", last != "..", !last.hasPrefix(".") else { return nil }
    return last
  }
}
