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

  /// Connects to `computer`, takes its dives newest first up to the entry holding the stored
  /// fingerprint, and disconnects.
  ///
  /// The stream yields ``DiveComputerDownloadEvent/identified(_:)`` once the identity is known
  /// — once the device is open for a family that advertises its serial, whose name gave it
  /// before connecting, and from the computer's own answers otherwise — and calls `lookup` at
  /// that moment, folding the serial's case. It yields the identity again where a later answer
  /// adds the firmware or the hardware.
  /// It takes only the entries newer than the one holding the
  /// ``DiveComputerRecord/fingerprint`` of the record `lookup` returns, and every entry where
  /// `lookup` returns no record or one with no fingerprint. Then the watch's zone where
  /// the family logs instants and the watch reports one;
  /// ``DiveComputerDownloadEvent/busy(_:)`` whenever the computer says it is busy, again once it
  /// says it is free, and each time another app's handshake broke a transfer; once, where the
  /// family lists
  /// its entries before reading them, ``DiveComputerDownloadEvent/listing(_:)`` with the walk's
  /// count; progress where the family reports it, each dive as it is read — or
  /// ``DiveComputerDownloadEvent/skipped(fingerprint:)`` for an entry left out — and last
  /// ``DiveComputerDownloadEvent/finished(_:)``.
  ///
  /// `waiting` says whether the dive of an identity and fingerprint is one the phone need not
  /// take again; a family that lists its entries leaves such an entry out and does not count it
  /// new. `keep` is called with each dive, on the walk's own thread, before the dive is yielded
  /// and before the next transfer starts.
  ///
  /// With `pairedOnly`, a computer whose family and serial `lookup` finds no record of is closed
  /// as soon as it is identified, with none of its entries listed or read, and the stream ends
  /// ``DiveComputerDownloadEnd/Kind/unpaired``.
  func download(
    _ computer: FoundComputer, pairedOnly: Bool,
    lookup: @escaping @Sendable (DiveComputerFamily, String) -> DiveComputerRecord?,
    waiting: @escaping @Sendable (DiveComputerIdentity, Data) -> Bool,
    keep: @escaping @Sendable (DownloadedDive) -> Void
  ) -> AsyncStream<DiveComputerDownloadEvent>

  /// The computer a paired record names, to open under the Core Bluetooth identifier it was
  /// last seen under: what a walk nobody started from a scan opens.
  func computer(for record: DiveComputerRecord, at peripheral: UUID) -> FoundComputer

  /// Stops the walk between dives; the stream still finishes, with
  /// ``DiveComputerDownloadEnd/Kind/cancelled``.
  func cancelDownload()
}
