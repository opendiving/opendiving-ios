@preconcurrency import Clibdivecomputer
import Foundation
@preconcurrency import LibDCBridge
@preconcurrency import LibDCSwift
import OpenDivingKit
import Synchronization

/// Each download's device, opened for one walk and closed after it, confined to one serial
/// queue: libdivecomputer's calls block for as long as the computer takes to answer, and its
/// callbacks run on the thread that called it.
///
/// The device is opened through the bridge's C entry, not libdc-swift's `openBLEDevice`, which
/// records every device it opens in `UserDefaults`; and the dives are walked with
/// `dc_device_foreach` and a callback of this class's, not libdc-swift's retriever, which keeps
/// no dive's bytes.
nonisolated final class LibDCDeviceSession: @unchecked Sendable {
  /// What libdc-swift writes to `UserDefaults` under its own keys, removed after every session
  /// so nothing the package keeps about a computer outlives one.
  static let packageDefaultsKeys = ["DeviceFingerprints", "com.libdc.storedDevices"]

  let queue = DispatchQueue(label: "app.opendiving.dive-computer", qos: .userInitiated)
  private let defaults: UserDefaults

  init(defaults: UserDefaults) {
    self.defaults = defaults
  }

  /// Opens the computer, walks it, and closes it.
  func download(
    _ computer: FoundComputer, cancel: CancelFlag,
    lookup: @escaping @Sendable (DiveComputerFamily, String) -> DiveComputerRecord?,
    into events: AsyncStream<DiveComputerDownloadEvent>.Continuation
  ) {
    dispatchPrecondition(condition: .onQueue(queue))
    defer { events.finish() }
    var opened: UnsafeMutablePointer<device_data_t>?
    let family = computer.family.flatMap(LibDCNames.dcFamily) ?? DC_FAMILY_NULL
    let status = open_ble_device_with_identification(
      &opened, computer.name, computer.id.uuidString, family, computer.modelNumber ?? 0)
    guard status == DC_STATUS_SUCCESS, let device = opened else {
      clearPackageDefaults()
      events.yield(.finished(.init(Self.openFailure(status))))
      return
    }

    let walk = LibDCWalk(
      computer: computer, device: device, cancel: cancel, lookup: lookup, events: events)
    events.yield(.finished(walk.run()))
    // Closed after every walk, not kept for the next: a Perdix 3 answers a second dive-index
    // read in one session with an all-zero index, so a walk over a device left open finds no
    // dives.
    close(device)
  }

  /// A link or handshake that failed reads as a computer that did not answer; anything else keeps
  /// libdivecomputer's status.
  static func openFailure(_ status: dc_status_t) -> DiveComputerDownloadEnd.Kind {
    switch status {
    case DC_STATUS_IO, DC_STATUS_TIMEOUT, DC_STATUS_NODEVICE, DC_STATUS_PROTOCOL: .unreachable
    default: .failed(status: LibDCNames.status(status))
    }
  }

  /// Closes the device and its link, and removes what the package wrote about it.
  func close(_ device: UnsafeMutablePointer<device_data_t>) {
    dispatchPrecondition(condition: .onQueue(queue))
    defer { clearPackageDefaults() }
    if let handle = device.pointee.device {
      dc_device_close(handle)
      // The close sends the computer a shutdown command whose write is still flushing; cutting
      // the link at once leaves the computer waiting on a command that never ends.
      usleep(500_000)
    }
    if let stream = device.pointee.iostream { dc_iostream_close(stream) }
    if let context = device.pointee.context { dc_context_free(context) }
    if let descriptor = device.pointee.descriptor { dc_descriptor_free(descriptor) }
    free(device.pointee.fingerprint)
    free(UnsafeMutableRawPointer(mutating: device.pointee.model))
    free(device)
  }

  func clearPackageDefaults() {
    for key in Self.packageDefaultsKeys { defaults.removeObject(forKey: key) }
  }
}

/// The cancellation the model asks for, read by libdivecomputer between dives.
nonisolated final class CancelFlag: Sendable {
  private let value = Atomic(false)

  var isSet: Bool { value.load(ordering: .relaxed) }

  func set(_ cancelled: Bool) { value.store(cancelled, ordering: .relaxed) }
}
