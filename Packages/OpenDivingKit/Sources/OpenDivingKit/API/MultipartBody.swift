import Foundation

/// One part of a `multipart/form-data` body: a form field, or a file whose bytes are read
/// from disk while the body is written.
struct MultipartPart: Sendable {
  enum Content: Sendable {
    case data(Data)
    case file(URL)
  }

  var name: String
  var filename: String?
  var contentType: String?
  var content: Content

  static func field(_ name: String, _ value: String) -> MultipartPart {
    MultipartPart(name: name, content: .data(Data(value.utf8)))
  }
}

/// Writes a `multipart/form-data` body to a file, one part at a time and a file part a chunk
/// at a time, so a body of many megabytes is never in memory with the files it carries.
enum MultipartBody {
  private static let chunkSize = 1 << 20

  static func boundary() -> String {
    "OpenDiving-" + UUID().uuidString
  }

  static func contentType(boundary: String) -> String {
    "multipart/form-data; boundary=\(boundary)"
  }

  /// A new file under the temporary directory holding the body; the caller removes it.
  static func write(_ parts: [MultipartPart], boundary: String) throws -> URL {
    let file = FileManager.default.temporaryDirectory
      .appendingPathComponent("OpenDiving-upload-\(UUID().uuidString)", isDirectory: false)
    guard FileManager.default.createFile(atPath: file.path, contents: nil) else {
      throw CocoaError(.fileWriteUnknown)
    }
    do {
      let output = try FileHandle(forWritingTo: file)
      defer { try? output.close() }
      for part in parts {
        try output.write(contentsOf: Data(header(part, boundary: boundary).utf8))
        switch part.content {
        case .data(let data):
          try output.write(contentsOf: data)
        case .file(let url):
          let input = try FileHandle(forReadingFrom: url)
          defer { try? input.close() }
          while let chunk = try input.read(upToCount: chunkSize), !chunk.isEmpty {
            try output.write(contentsOf: chunk)
          }
        }
        try output.write(contentsOf: Data("\r\n".utf8))
      }
      try output.write(contentsOf: Data("--\(boundary)--\r\n".utf8))
    } catch {
      try? FileManager.default.removeItem(at: file)
      throw error
    }
    return file
  }

  private static func header(_ part: MultipartPart, boundary: String) -> String {
    var disposition = "form-data; name=\"\(quoted(part.name))\""
    if let filename = part.filename {
      disposition += "; filename=\"\(quoted(filename))\""
    }
    var header = "--\(boundary)\r\nContent-Disposition: \(disposition)\r\n"
    if let contentType = part.contentType {
      header += "Content-Type: \(contentType)\r\n"
    }
    return header + "\r\n"
  }

  /// The escaping the HTML standard gives a browser's form submission: a quote and a line
  /// break cannot appear raw inside the quoted name.
  private static func quoted(_ text: String) -> String {
    text.replacingOccurrences(of: "\"", with: "%22")
      .replacingOccurrences(of: "\r", with: "%0D")
      .replacingOccurrences(of: "\n", with: "%0A")
  }
}
