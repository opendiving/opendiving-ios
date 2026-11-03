@preconcurrency import Clibdivecomputer
import Foundation
@preconcurrency import LibDCBridge
@preconcurrency import LibDCSwift
import OpenDivingKit
import Synchronization

/// Each download's device, opened for one walk and closed after it, confined to one serial
/// queue: libdivecomputer's calls block for as long as the computer takes to answer, and its
/// callbacks run on the thread that called it. An Ocean walk that times out closes and reopens it
/// (``LibDCWalk``), so the device closed at the end is whichever the walk holds open then.
///
/// The device is opened through the bridge's C entry, not libdc-swift's `openBLEDevice`, which
/// records every device it opens in `UserDefaults`; and the dives are walked by ``LibDCWalk``, not
/// libdc-swift's retriever, which keeps no dive's bytes.
nonisolated final class LibDCDeviceSession: @unchecked Sendable {
  /// What libdc-swift writes to `UserDefaults` under its own keys, removed after every session
  /// so nothing the package keeps about a computer outlives one.
  static let packageDefaultsKeys = ["DeviceFingerprints", "com.libdc.storedDevices"]

  let queue = DispatchQueue(label: "app.opendiving.dive-computer", qos: .userInitiated)
  let log = DiveComputerLog.device
  private let defaults: UserDefaults

  init(defaults: UserDefaults) {
    self.defaults = defaults
    Self.routeLibraryLog()
  }

  /// Opens the computer, walks it, and closes it, logging each step to a log started afresh.
  func download(
    _ computer: FoundComputer, cancel: CancelFlag,
    lookup: @escaping @Sendable (DiveComputerFamily, String) -> DiveComputerRecord?,
    waiting: @escaping @Sendable (DiveComputerIdentity, Data) -> Bool,
    into events: AsyncStream<DiveComputerDownloadEvent>.Continuation
  ) {
    dispatchPrecondition(condition: .onQueue(queue))
    defer { events.finish() }
    log.start()
    log.write("download \(computer.name)")
    let (status, opened) = open(computer)
    guard let device = opened else {
      clearPackageDefaults()
      events.yield(.finished(.init(Self.openFailure(status))))
      return
    }

    // The resume buffer outlives every device the walk opens, each of which points at it.
    let resume = dc_buffer_new(0)
    defer { if let resume { dc_buffer_free(resume) } }
    let walk = LibDCWalk(
      computer: computer, device: device, session: self, resume: resume, cancel: cancel,
      lookup: lookup, waiting: waiting, events: events)
    let end = walk.run()
    log.write("end \(end.kind)")
    events.yield(.finished(end))
    // Closed after every walk, not kept for the next: a Perdix 3 answers a second dive-index
    // read in one session with an all-zero index, so a walk over a device left open finds no
    // dives. A walk whose reopen failed holds none.
    if let device = walk.device { close(device) }
  }

  /// Opens the computer through the bridge's C entry: its status, and the device where it opened.
  /// It cannot be interrupted, and waits up to 10 s for the link and 5 s for a reply.
  func open(_ computer: FoundComputer) -> (dc_status_t, UnsafeMutablePointer<device_data_t>?) {
    dispatchPrecondition(condition: .onQueue(queue))
    let began = Date.now
    var opened: UnsafeMutablePointer<device_data_t>?
    let family = computer.family.flatMap(LibDCNames.dcFamily) ?? DC_FAMILY_NULL
    let status = open_ble_device_with_identification(
      &opened, computer.name, computer.id.uuidString, family, computer.modelNumber ?? 0)
    log.write("open \(LibDCNames.status(status)) \(Self.milliseconds(since: began)) ms")
    return status == DC_STATUS_SUCCESS ? (status, opened) : (status, nil)
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
    let began = Date.now
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
    log.write("close \(Self.milliseconds(since: began)) ms")
  }

  func clearPackageDefaults() {
    for key in Self.packageDefaultsKeys { defaults.removeObject(forKey: key) }
  }

  static func milliseconds(since began: Date) -> Int {
    Int((Date.now.timeIntervalSince(began) * 1000).rounded())
  }

  /// Runs one libdivecomputer call on the queue: what it returned, and whether the library logged,
  /// during it, another app's handshake on a Nautic link (``NauticLinkLog``). The log sink calls
  /// back inline on the calling thread, so the lines counted between the reset and the read are
  /// this call's.
  func watchingOtherApp<Result>(_ call: () -> Result) -> (result: Result, otherApp: Bool) {
    dispatchPrecondition(condition: .onQueue(queue))
    otherAppLines.store(0, ordering: .relaxed)
    let result = call()
    return (result, otherAppLines.load(ordering: .relaxed) > 0)
  }

  /// libdivecomputer's ERROR and WARN lines, from every context the bridge's open creates, go to
  /// the device's log. The sink is global to the bridge, so it is set once.
  private static let libraryLogRouted: Void = set_libdc_log_sink(libraryLogSink)

  private static func routeLibraryLog() { _ = libraryLogRouted }
}

extension DiveComputerLog {
  /// The phone's: one file in Application Support, outside every server's directory.
  nonisolated static let device = DiveComputerLog(
    file: URL.applicationSupportDirectory.appendingPathComponent("dive-computer.log"))
}

/// The lines showing another app on the link since ``LibDCDeviceSession/watchingOtherApp(_:)``
/// last reset it; global, as the sink that counts them is.
private nonisolated let otherAppLines = Atomic(0)

private nonisolated let libraryLogSink:
  @convention(c) (UnsafePointer<CChar>?, UnsafePointer<CChar>?) -> Void = { level, message in
    let level = level.map { String(cString: $0) } ?? "?"
    let message = message.map { String(cString: $0) } ?? ""
    if NauticLinkLog.showsOtherApp(message) { otherAppLines.add(1, ordering: .relaxed) }
    DiveComputerLog.device.write("libdc \(level) \(message)")
  }

/// The cancellation the model asks for, read by the walk between its steps and by libdivecomputer
/// before each transfer.
nonisolated final class CancelFlag: Sendable {
  private let value = Atomic(false)

  var isSet: Bool { value.load(ordering: .relaxed) }

  func set(_ cancelled: Bool) { value.store(cancelled, ordering: .relaxed) }
}
