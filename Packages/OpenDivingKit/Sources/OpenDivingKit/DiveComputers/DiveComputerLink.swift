import Foundation

/// The phone's Bluetooth link to dive computers. A protocol because the Kit builds where Core
/// Bluetooth and libdivecomputer do not: the app target conforms it over libdc-swift, and the
/// Kit's tests over a fake that replays a scripted download.
@MainActor
public protocol DiveComputerLink: AnyObject {
  /// Bluetooth's state now, then each change, until the caller stops listening.
  func availability() -> AsyncStream<DiveComputerAvailability>

  /// The computers found advertising, each as often as it is seen. Scanning stops when the
  /// caller stops listening.
  func scan() -> AsyncStream<FoundComputer>

  /// Connects to `computer`, or keeps the connection a previous download left open, and walks
  /// its dives newest first.
  ///
  /// The stream yields ``DiveComputerDownloadEvent/identified(_:)`` once the identity is known
  /// — once the device is open for a family that advertises its serial, whose name gave it
  /// before connecting, and from the device info otherwise — and calls `lookup` at that moment,
  /// folding the serial's case. It yields the identity again where the device info later adds
  /// the firmware.
  /// It sets the fingerprint of the record `lookup` returns on the open device before any dive
  /// is read, and sets none — clearing one an earlier walk on the same device set — when
  /// `lookup` returns nil. Then the watch's zone where the family logs instants and the watch
  /// reports one, progress where the family reports it, each dive as it is read, and last
  /// ``DiveComputerDownloadEvent/finished(_:)``.
  func download(
    _ computer: FoundComputer,
    lookup: @escaping @Sendable (DiveComputerFamily, String) -> DiveComputerRecord?
  ) -> AsyncStream<DiveComputerDownloadEvent>

  /// Stops the walk between dives; the stream still finishes, with
  /// ``DiveComputerDownloadEnd/Kind/cancelled``.
  func cancelDownload()

  /// Closes the connection a download left open.
  func disconnect()
}
