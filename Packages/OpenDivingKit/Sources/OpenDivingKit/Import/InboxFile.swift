import Foundation

/// One file kept in an account's inbox until it is imported.
public struct InboxFile: Codable, Hashable, Sendable, Identifiable {
  /// The file's own name on disk, so two files of one name are two files.
  public let id: UUID
  /// The name it arrived under, which is the part's filename when it is sent.
  public let filename: String
  public let byteSize: Int
  public let arrivedAt: Date
  /// Received while signed in before the account had loaded, into the inbox of the account
  /// last loaded: it moves if the load names another account.
  public var receivedBeforeAccountKnown: Bool
  /// Set on an archive downloaded from dive computers. A build before it reads the file as
  /// any other and drops the member at its next save.
  public var download: InboxDownload?
  /// The import an upload put it in, for as long as the phone keeps it for that import: such a
  /// file is no longer waiting to upload, and leaves once the import is seen applied.
  public var uploadedInto: UUID?

  public init(
    id: UUID = UUID(), filename: String, byteSize: Int, arrivedAt: Date = Date(),
    receivedBeforeAccountKnown: Bool = false, download: InboxDownload? = nil,
    uploadedInto: UUID? = nil
  ) {
    self.id = id
    self.filename = filename
    self.byteSize = byteSize
    self.arrivedAt = arrivedAt
    self.receivedBeforeAccountKnown = receivedBeforeAccountKnown
    self.download = download
    self.uploadedInto = uploadedInto
  }
}
