import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

extension APIClient {
  /// `GET /export/{format}`: the account's whole logbook, written to a file as it arrives —
  /// the archive can be as large as everything the account stores. The file lands in a new
  /// directory under `directory`, named as the server's `Content-Disposition` names it. A
  /// refusal, the hourly limit's included, is the API's sentence.
  public func export(_ format: ExportFormat, into directory: URL) async throws -> ExportedFile {
    let (body, response) = try await authorizedDownload(Call(path: format.path))
    defer { try? FileManager.default.removeItem(at: body) }
    guard (200..<300).contains(response.statusCode) else {
      try check((try? Data(contentsOf: body)) ?? Data(), response)
      throw APIError.http(status: response.statusCode, message: nil)
    }
    let name =
      ExportedFile.filename(
        contentDisposition: response.value(forHTTPHeaderField: "Content-Disposition"))
      ?? format.fallbackFilename
    let folder = directory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let file = ExportedFile(url: folder.appendingPathComponent(name))
    do {
      try FileManager.default.moveItem(at: body, to: file.url)
    } catch {
      file.remove()
      throw error
    }
    return file
  }
}
