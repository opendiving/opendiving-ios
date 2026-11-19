import Foundation

/// A dive-computer export a recording was read from — its metadata, never its bytes.
public struct DiveFileInfo: Codable, Hashable, Sendable {
  public let uuid: UUID
  public let originalFilename: String
  public let contentType: String
  public let byteSize: Int
  public let parserKey: String
  /// When the file was uploaded.
  public let createdAt: DiveTimestamp
  public let updatedAt: DiveTimestamp?
}
