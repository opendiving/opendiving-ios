import Foundation

/// A dive-computer export a recording was read from — its metadata, never its bytes.
public struct DiveFileInfo: Codable, Hashable, Sendable {
  public let uuid: UUID
  public let originalFilename: String
  public let contentType: String
  public let byteSize: Int
  public let parserKey: String
  public let updatedAt: DiveTimestamp?
}
