import Foundation

/// One stored side of a c-card — its metadata; the bytes come from
/// `GET /certification/{uuid}/file/{side}`.
public struct CertificationFileInfo: Codable, Hashable, Sendable {
  public let uuid: UUID
  /// `front` or `back`.
  public let side: String
  public let contentType: String
  public let byteSize: Int
  public let originalFilename: String
  public let updatedAt: DiveTimestamp?
}
