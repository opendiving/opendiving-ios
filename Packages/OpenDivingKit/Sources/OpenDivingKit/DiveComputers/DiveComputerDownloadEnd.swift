/// How a download ended.
public struct DiveComputerDownloadEnd: Hashable, Sendable {
  public enum Kind: Hashable, Sendable {
    /// The walk reached the stored fingerprint or the last dive.
    case complete
    case cancelled
    /// The connection never opened: the computer is off, asleep or out of range.
    case unreachable
    /// libdivecomputer's status, by name: `DC_STATUS_PROTOCOL`.
    case failed(status: String)
    /// The computer that answered has no pairing on the phone, and was closed unread.
    case unpaired
  }

  public let kind: Kind
  /// Records with no samples and no duration, skipped. A download that met one never advances
  /// the fingerprint. The Nautic family's are empty or aborted sessions, yielded as
  /// ``DiveComputerDownloadEvent/skipped(fingerprint:)`` instead and never counted here.
  public let emptyReads: Int
  /// Records the parser could not read, delivered as ``DownloadedDive/Reading/refused(start:)``.
  public let refused: Int
  /// New entries left out because the phone need not take their dive again — it waits to be
  /// imported, or the server has answered for it — yielded as
  /// ``DiveComputerDownloadEvent/skipped(fingerprint:)``.
  public let waiting: Int
  /// Entries left out because their download failed the same way on every attempt, yielded as
  /// ``DiveComputerDownloadEvent/skipped(fingerprint:)``; *Download all dives* tries them again.
  public let notDownloaded: Int

  public init(
    _ kind: Kind, emptyReads: Int = 0, refused: Int = 0, waiting: Int = 0, notDownloaded: Int = 0
  ) {
    self.kind = kind
    self.emptyReads = emptyReads
    self.refused = refused
    self.waiting = waiting
    self.notDownloaded = notDownloaded
  }
}
