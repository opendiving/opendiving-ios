import Foundation

/// One step of a download.
public enum DiveComputerDownloadEvent: Hashable, Sendable {
  case identified(DiveComputerIdentity)
  /// The zone the watch's own settings report, for a family that logs instants.
  case watchZone(TimeZone)
  /// Another app holding the computer: ``DiveComputerBusy/reported`` while the computer says it is
  /// busy and ``DiveComputerBusy/free`` once it says it is free, or
  /// ``DiveComputerBusy/otherApp`` each time another app's handshake broke a transfer. At any
  /// point of the walk, from a family that can tell.
  case busy(DiveComputerBusy)
  /// The walk's count, once, after ``identified(_:)`` and before the first dive or skip, from a
  /// family the app lists before it downloads.
  case listing(DiveComputerListing)
  /// libdivecomputer's progress, in the backend's own units.
  case progress(current: Int, maximum: Int)
  case dive(DownloadedDive)
  /// An entry the walk left out — one the computer logged that is no dive, a Suunto watch's run
  /// or a session that holds none, its profile unread where its summary named the sport; one
  /// whose dive already waits in the import screen; or one whose download kept failing. Only its
  /// fingerprint is kept, which the record moves past as it does a dive's.
  case skipped(fingerprint: Data)
  case finished(DiveComputerDownloadEnd)
}
