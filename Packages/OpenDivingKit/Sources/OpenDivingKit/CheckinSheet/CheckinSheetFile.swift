/// One picture the cached sheet keeps on disk: the portrait, or one side of a card.
public struct CheckinSheetFile: Codable, Hashable, Sendable {
  /// The file's name among the sheet's files: `portrait`, or a card side's file uuid.
  public let name: String
  /// Which bytes these are: the account's `portrait_sha256`, or the side's file uuid. A
  /// different version is a different file, asked for without the stored `ETag`.
  public let version: String
  public let etag: String?
  public let contentType: String?

  public init(name: String, version: String, etag: String?, contentType: String?) {
    self.name = name
    self.version = version
    self.etag = etag
    self.contentType = contentType
  }

  public var isPDF: Bool { contentType == "application/pdf" }
}
