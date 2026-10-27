/// How a download ended.
public struct DiveComputerDownloadEnd: Hashable, Sendable {
  public enum Kind: Hashable, Sendable {
    /// The walk reached the stored fingerprint or the last dive.
    case complete
    case cancelled
    /// libdivecomputer's status, by name: `DC_STATUS_PROTOCOL`.
    case failed(status: String)
  }

  public let kind: Kind
  /// Records with no samples and no duration, skipped: on the Nautic family a sign of the
  /// Suunto app still holding the link. A download that met one never advances the fingerprint.
  public let emptyReads: Int
  /// Records the parser could not read, delivered as ``DownloadedDive/Reading/refused(start:)``.
  public let refused: Int

  public init(_ kind: Kind, emptyReads: Int = 0, refused: Int = 0) {
    self.kind = kind
    self.emptyReads = emptyReads
    self.refused = refused
  }
}
