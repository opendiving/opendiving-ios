import Foundation

/// One file waiting in an account's inbox to be imported.
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

  public init(
    id: UUID = UUID(), filename: String, byteSize: Int, arrivedAt: Date = Date(),
    receivedBeforeAccountKnown: Bool = false, download: InboxDownload? = nil
  ) {
    self.id = id
    self.filename = filename
    self.byteSize = byteSize
    self.arrivedAt = arrivedAt
    self.receivedBeforeAccountKnown = receivedBeforeAccountKnown
    self.download = download
  }
}
