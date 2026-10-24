import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// A file to import, read from disk while the request is written.
public struct ImportFile: Hashable, Sendable {
  public var file: URL
  /// The name the server reports the file under, and digests into the preview's token.
  public var filename: String
  public var contentType: String

  public init(file: URL, filename: String, contentType: String = "application/octet-stream") {
    self.file = file
    self.filename = filename
    self.contentType = contentType
  }
}

// The logbook import: any number of files, each a `file` part, previewed and then applied.
// The token digests each part's name and bytes, so the apply sends the same files in the
// same order under the same names, and a different set is a 422.
extension APIClient {
  /// `POST /import/logbook/preview`: what importing `files` would do. Stores nothing.
  public func importPreview(files: [ImportFile]) async throws -> ImportPreview {
    try await authorizedDecoded(
      ImportPreview.self,
      Call(method: "POST", path: "import/logbook/preview", parts: Self.fileParts(files)))
  }

  /// `POST /import/logbook`: imports `files` under the preview's `token`. `checkInDetails` and
  /// `portrait` are the diver's answers to what the preview offered, sent only when given.
  public func importApply(
    files: [ImportFile], token: String, checkInDetails: ImportCheckInSubmission? = nil,
    portrait: ImportPortraitChoice? = nil
  ) async throws -> ImportResult {
    var parts = [MultipartPart.field("token", token)]
    if let checkInDetails {
      parts.append(
        .field("check_in_details", String(decoding: try Self.json(checkInDetails), as: UTF8.self)))
    }
    if let portrait {
      parts.append(.field("portrait", String(decoding: try Self.json(portrait), as: UTF8.self)))
    }
    return try await authorizedDecoded(
      ImportResult.self,
      Call(method: "POST", path: "import/logbook", parts: parts + Self.fileParts(files)))
  }

  private static func fileParts(_ files: [ImportFile]) -> [MultipartPart] {
    files.map {
      MultipartPart(
        name: "file", filename: $0.filename, contentType: $0.contentType, content: .file($0.file))
    }
  }
}
