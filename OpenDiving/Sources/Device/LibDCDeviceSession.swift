@preconcurrency import Clibdivecomputer
import Foundation
@preconcurrency import LibDCBridge
@preconcurrency import LibDCSwift
import OpenDivingKit
import Synchronization

/// The open device and the walks over it, confined to one serial queue: libdivecomputer's calls
/// block for as long as the computer takes to answer, and its callbacks run on the thread that
/// called it.
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
  /// Only touched on ``queue``.
  private var open: (computer: UUID, device: UnsafeMutablePointer<device_data_t>)?

  init(defaults: UserDefaults) {
    self.defaults = defaults
  }

  /// Opens the computer, or keeps the device a previous walk left open, and walks it.
  func download(
    _ computer: FoundComputer, cancel: CancelFlag,
    lookup: @escaping @Sendable (DiveComputerFamily, String) -> DiveComputerRecord?,
    into events: AsyncStream<DiveComputerDownloadEvent>.Continuation
  ) {
    dispatchPrecondition(condition: .onQueue(queue))
    defer { events.finish() }
    if let open, open.computer != computer.id { close() }
    let device: UnsafeMutablePointer<device_data_t>
    if let open {
      device = open.device
    } else {
      var opened: UnsafeMutablePointer<device_data_t>?
      let family = computer.family.flatMap(LibDCNames.dcFamily) ?? DC_FAMILY_NULL
      let status = open_ble_device_with_identification(
        &opened, computer.name, computer.id.uuidString, family, computer.modelNumber ?? 0)
      guard status == DC_STATUS_SUCCESS, let opened else {
        clearPackageDefaults()
        events.yield(.finished(.init(.failed(status: LibDCNames.status(status)))))
        return
      }
      device = opened
      open = (computer.id, opened)
    }

    let walk = LibDCWalk(
      computer: computer, device: device, cancel: cancel, lookup: lookup, events: events)
    let end = walk.run()
    events.yield(.finished(end))
    if case .failed = end.kind { close() }
  }

  /// Closes the device and its link, and removes what the package wrote about it.
  func close() {
    dispatchPrecondition(condition: .onQueue(queue))
    defer { clearPackageDefaults() }
    guard let device = open?.device else { return }
    open = nil
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
