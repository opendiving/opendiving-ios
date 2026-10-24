import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// One part of a `multipart/form-data` body as a server reads it.
struct ReceivedPart: Equatable {
  let name: String
  let filename: String?
  let contentType: String?
  let bytes: Data

  /// Splits `request`'s body by the boundary its `Content-Type` names.
  static func parts(of request: URLRequest) throws -> [ReceivedPart] {
    guard
      let header = request.value(forHTTPHeaderField: "Content-Type"),
      header.hasPrefix("multipart/form-data; boundary="),
      let body = request.httpBody
    else { throw MalformedMultipart() }
    let boundary = Data(("--" + header.dropFirst("multipart/form-data; boundary=".count)).utf8)
    var parts: [ReceivedPart] = []
    var cursor = try range(of: boundary, in: body, from: body.startIndex).upperBound
    while body[cursor..<min(cursor + 2, body.endIndex)] == Data("\r\n".utf8) {
      let headersEnd = try range(of: Data("\r\n\r\n".utf8), in: body, from: cursor + 2)
      let headers = String(decoding: body[(cursor + 2)..<headersEnd.lowerBound], as: UTF8.self)
      let next = try range(of: Data("\r\n".utf8) + boundary, in: body, from: headersEnd.upperBound)
      parts.append(
        ReceivedPart(
          headers: headers, bytes: Data(body[headersEnd.upperBound..<next.lowerBound])))
      cursor = next.upperBound
    }
    guard body[cursor...] == Data("--\r\n".utf8) else { throw MalformedMultipart() }
    return parts
  }

  private init(headers: String, bytes: Data) {
    var name = ""
    var filename: String?
    var contentType: String?
    for line in headers.components(separatedBy: "\r\n") {
      if line.hasPrefix("Content-Disposition: form-data; ") {
        for field in line.dropFirst("Content-Disposition: form-data; ".count)
          .components(separatedBy: "; ")
        {
          let pair = field.split(separator: "=", maxSplits: 1).map(String.init)
          let value = String(pair[1].dropFirst().dropLast())
          if pair[0] == "name" { name = value }
          if pair[0] == "filename" { filename = value }
        }
      } else if line.hasPrefix("Content-Type: ") {
        contentType = String(line.dropFirst("Content-Type: ".count))
      }
    }
    self.name = name
    self.filename = filename
    self.contentType = contentType
    self.bytes = bytes
  }

  init(name: String, filename: String?, contentType: String?, bytes: Data) {
    self.name = name
    self.filename = filename
    self.contentType = contentType
    self.bytes = bytes
  }

  private static func range(of needle: Data, in data: Data, from start: Data.Index) throws
    -> Range<Data.Index>
  {
    guard let found = data.range(of: needle, in: start..<data.endIndex) else {
      throw MalformedMultipart()
    }
    return found
  }

  struct MalformedMultipart: Error {}
}
