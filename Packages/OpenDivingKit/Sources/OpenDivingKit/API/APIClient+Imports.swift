import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// A file to import, read from disk while the request is written.
public struct ImportFile: Hashable, Sendable {
  public var file: URL
  /// The name the server reports the file under.
  public var filename: String
  public var contentType: String

  public init(file: URL, filename: String, contentType: String = "application/octet-stream") {
    self.file = file
    self.filename = filename
    self.contentType = contentType
  }
}

// The logbook import: an upload of any number of files, each a `file` part, that the server
// holds as one pending import per account until it is applied or discarded, from any device —
// or writes at once, holding nothing.
extension APIClient {
  /// `POST /imports`: uploads `files` once, for the server to hold and review. Writes nothing to
  /// the logbook; a 409 while the account has a pending import.
  public func uploadImport(files: [ImportFile]) async throws -> LogbookImportRead {
    try await authorizedDecoded(
      LogbookImportRead.self, Call(method: "POST", path: "imports", parts: Self.fileParts(files)))
  }

  /// `POST /imports?apply=true`: uploads `files` and writes them at once, answering the applied
  /// import, with no review and no pending import. Under one `idempotencyKey` a repeat writes
  /// nothing and answers the import the first made; a 409 while that first is still running and
  /// a 410 once its import is gone. A server that cannot apply in one request ignores the query
  /// and answers as ``uploadImport(files:)`` does.
  public func importAtOnce(files: [ImportFile], idempotencyKey: UUID) async throws
    -> LogbookImportRead
  {
    try await authorizedDecoded(
      LogbookImportRead.self,
      Call(
        method: "POST", path: "imports", query: [URLQueryItem(name: "apply", value: "true")],
        parts: Self.fileParts(files), headers: ["Idempotency-Key": Self.wire(idempotencyKey)]))
  }

  /// `GET /imports`: the applied imports, most recently applied first.
  public func imports(page: Int, itemsPerPage: Int = listPageSize) async throws
    -> PaginatedListResponse<LogbookImportSummary>
  {
    try await authorizedDecoded(
      PaginatedListResponse<LogbookImportSummary>.self,
      Call(path: "imports", query: Self.paging(page, itemsPerPage)))
  }

  /// `GET /imports/pending`: the account's pending import, whichever device uploaded it; a 404
  /// when there is none.
  public func pendingImport() async throws -> LogbookImportRead {
    try await authorizedDecoded(LogbookImportRead.self, Call(path: "imports/pending"))
  }

  /// `GET /import/{uuid}`, pending or applied; a 404 for one that is gone.
  public func logbookImport(_ uuid: UUID) async throws -> LogbookImportRead {
    try await authorizedDecoded(
      LogbookImportRead.self, Call(path: "import/\(Self.wire(uuid))"))
  }

  /// `GET /import/{uuid}/notes`: the import's log.
  public func importNotes(_ uuid: UUID) async throws -> LogbookImportNotes {
    try await authorizedDecoded(
      LogbookImportNotes.self, Call(path: "import/\(Self.wire(uuid))/notes"))
  }

  /// `POST /import/{uuid}/apply`: writes the import as reviewed, from the files the server holds.
  /// A 409 when it is already applied.
  public func applyImport(_ uuid: UUID, _ choices: LogbookImportApply) async throws
    -> LogbookImportRead
  {
    try await authorizedDecoded(
      LogbookImportRead.self,
      Call(method: "POST", path: "import/\(Self.wire(uuid))/apply", body: Self.json(choices)))
  }

  /// `DELETE /import/{uuid}`: discards a pending import, or leaves an applied one out of the
  /// history. `status` is the one the caller means to delete; a 409 when the import's is another.
  public func deleteImport(_ uuid: UUID, status: String) async throws {
    try await authorizedChecked(
      Call(
        method: "DELETE", path: "import/\(Self.wire(uuid))",
        query: [URLQueryItem(name: "status", value: status)]))
  }

  private static func fileParts(_ files: [ImportFile]) -> [MultipartPart] {
    files.map {
      MultipartPart(
        name: "file", filename: $0.filename, contentType: $0.contentType, content: .file($0.file))
    }
  }
}
