import Foundation

/// One step of a download.
public enum DiveComputerDownloadEvent: Hashable, Sendable {
  case identified(DiveComputerIdentity)
  /// The zone the watch's own settings report, for a family that logs instants.
  case watchZone(TimeZone)
  /// libdivecomputer's progress, in the backend's own units.
  case progress(current: Int, maximum: Int)
  case dive(DownloadedDive)
  case finished(DiveComputerDownloadEnd)
}
