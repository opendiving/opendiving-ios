import Foundation

/// One step of a download.
public enum DiveComputerDownloadEvent: Hashable, Sendable {
  case identified(DiveComputerIdentity)
  /// The zone the watch's own settings report, for a family that logs instants.
  case watchZone(TimeZone)
  /// Whether the computer says it is busy with another app: `true` while it does, `false` once
  /// it says it is free. Comes before ``listing(_:)``, from a family that can tell.
  case busy(Bool)
  /// The walk's count, once, after ``identified(_:)`` and before the first dive or skip, from a
  /// family the app lists before it downloads.
  case listing(DiveComputerListing)
  /// libdivecomputer's progress, in the backend's own units.
  case progress(current: Int, maximum: Int)
  case dive(DownloadedDive)
  /// An entry the computer logged that is not a dive — a Suunto watch's run — left out, its
  /// profile unread where its summary named the sport. Only its fingerprint is kept, which the
  /// record moves past as it does a dive's.
  case skipped(fingerprint: Data)
  case finished(DiveComputerDownloadEnd)
}
