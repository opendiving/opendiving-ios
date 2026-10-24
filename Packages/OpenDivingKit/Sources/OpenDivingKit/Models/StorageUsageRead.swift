/// `GET /user/storage`: what the account stores, in bytes, against its limit.
public struct StorageUsageRead: Codable, Hashable, Sendable {
  /// The sum of the three parts.
  public let usedBytes: Int
  /// Null when the instance sets no limit.
  public let limitBytes: Int?
  public let diveFilesBytes: Int
  public let certificationFilesBytes: Int
  public let picturesBytes: Int
}
