@preconcurrency import Clibdivecomputer
import Foundation
@preconcurrency import LibDCBridge
@preconcurrency import LibDCSwift
import OpenDivingKit

/// One walk over an opened device: the identity, the stored fingerprint, the watch's zone for a
/// family that logs instants, then each dive's bytes parsed as they arrive, and the outcome. Its
/// instance is the userdata of libdivecomputer's callbacks, all of which run on the session's queue
/// but the progress poll's. An Ocean walk may close the device and open it again
/// (``reconnect()``); ``device`` is whichever is open, and nil once the walk closed one it could
/// not reopen.
///
/// A Shearwater Petrel-family computer and a Suunto Nautic-family watch are walked by the app
/// itself — listed, counted, then downloaded dive by dive (`LibDCWalk+Petrel.swift`,
/// `LibDCWalk+Nautic.swift`) — since `dc_device_foreach` gives no count before its first dive and
/// downloads a watch's run before its sport can be read. Every other family is walked by
/// `dc_device_foreach`.
nonisolated final class LibDCWalk: @unchecked Sendable {
  let computer: FoundComputer
  private(set) var device: UnsafeMutablePointer<device_data_t>?
  let session: LibDCDeviceSession
  /// libdivecomputer's resume buffer, which carries an Ocean dive's received bytes over a failed
  /// attempt; the session frees it after the last device is closed.
  let resume: OpaquePointer?
  let cancel: CancelFlag
  let lookup: @Sendable (DiveComputerFamily, String) -> DiveComputerRecord?
  /// Whether a dive already waits in the import screen, which a walk that lists leaves out.
  let waiting: @Sendable (DiveComputerIdentity, Data) -> Bool
  let events: AsyncStream<DiveComputerDownloadEvent>.Continuation

  let family: DiveComputerFamily
  let dcFamily: dc_family_t
  let model: UInt32
  let vendor: String
  let product: String

  private(set) var identity: DiveComputerIdentity?
  private var fingerprintSet = false
  private(set) var delivered = 0
  private(set) var emptyReads = 0
  private(set) var refused = 0
  /// New entries left out as waiting in the import screen.
  var waitingSkipped = 0
  /// Entries left out because their download kept failing.
  var notDownloaded = 0
  /// The reopens made after a transfer that timed out.
  private(set) var reconnects = 0

  init(
    computer: FoundComputer, device: UnsafeMutablePointer<device_data_t>,
    session: LibDCDeviceSession, resume: OpaquePointer?, cancel: CancelFlag,
    lookup: @escaping @Sendable (DiveComputerFamily, String) -> DiveComputerRecord?,
    waiting: @escaping @Sendable (DiveComputerIdentity, Data) -> Bool,
    events: AsyncStream<DiveComputerDownloadEvent>.Continuation
  ) {
    self.computer = computer
    self.device = device
    self.session = session
    self.resume = resume
    self.cancel = cancel
    self.lookup = lookup
    self.waiting = waiting
    self.events = events
    let descriptor = device.pointee.descriptor
    dcFamily = descriptor.map(dc_descriptor_get_type) ?? DC_FAMILY_NULL
    model = descriptor.map(dc_descriptor_get_model) ?? computer.modelNumber ?? 0
    family =
      descriptor == nil
      ? computer.family ?? LibDCNames.family(dcFamily) : LibDCNames.family(dcFamily)
    vendor =
      descriptor.flatMap(dc_descriptor_get_vendor).map { String(cString: $0) }
      ?? computer.vendor ?? ""
    product =
      descriptor.flatMap(dc_descriptor_get_product).map { String(cString: $0) }
      ?? computer.product ?? computer.name
  }

  func run() -> DiveComputerDownloadEnd {
    guard let device, let handle = device.pointee.device else {
      return .init(.failed(status: LibDCNames.status(DC_STATUS_NODEVICE)))
    }
    adopt(handle)
    defer { if let handle = self.device?.pointee.device { release(handle) } }
    // By the open device's own family, which decides what its handle is.
    switch dc_device_get_type(handle) {
    case DC_FAMILY_SHEARWATER_PETREL:
      return walkPetrel(handle)
    case DC_FAMILY_SUUNTO_NAUTIC:
      // A watch whose name carries no serial has no identity before the library's walk gives one.
      guard let serial = computer.advertisedSerial else { return walkLibrary(device, handle) }
      return walkNautic(serial: serial)
    default:
      return walkLibrary(device, handle)
    }
  }

  /// Hooks the walk's cancel into a device it opened, before the device's first transfer, and
  /// hands a Nautic one the resume buffer.
  private func adopt(_ handle: OpaquePointer) {
    dc_device_set_cancel(handle, cancelCallback, Unmanaged.passUnretained(self).toOpaque())
    if dc_device_get_type(handle) == DC_FAMILY_SUUNTO_NAUTIC, let resume {
      suunto_nautic_device_set_resume(handle, resume)
    }
  }

  /// Unhooks the walk from a device about to be closed.
  private func release(_ handle: OpaquePointer) {
    dc_device_set_cancel(handle, nil, nil)
    if dc_device_get_type(handle) == DC_FAMILY_SUUNTO_NAUTIC {
      suunto_nautic_device_set_resume(handle, nil)
    }
  }

  /// The reopens a walk may make, as libdc-swift's own sync reconnects after a lost link.
  static let reconnectLimit = 3

  /// Whether a transfer that answered `status` closes and reopens the device, `made` reopens
  /// having been made: a timeout, while the walk has reopens left.
  static func reconnects(after status: dc_status_t, made: Int) -> Bool {
    status == DC_STATUS_TIMEOUT && made < reconnectLimit
  }

  /// Closes the device, waits about four seconds and opens it again through the session, until it
  /// opens or the walk's reopens are spent: nil once open, else the status the walk ends on. The
  /// identity, the record and the listing are the walk's and carry over. A cancel ends the wait at
  /// once, and the open, which cannot be interrupted, once it returns.
  func reconnect() -> dc_status_t? {
    var status = DC_STATUS_NODEVICE
    while reconnects < Self.reconnectLimit {
      reconnects += 1
      if let device {
        if let handle = device.pointee.device { release(handle) }
        session.close(device)
        self.device = nil
      }
      for _ in 0..<40 {
        if cancel.isSet { return DC_STATUS_CANCELLED }
        usleep(100_000)
      }
      log("reopen \(reconnects) of \(Self.reconnectLimit)")
      let (opened, reopened) = session.open(computer)
      status = opened
      guard let reopened else { continue }
      device = reopened
      guard let handle = reopened.pointee.device else { continue }
      adopt(handle)
      return cancel.isSet ? DC_STATUS_CANCELLED : nil
    }
    return status
  }

  /// A line in the download's log.
  func log(_ line: String) {
    session.log.write(line)
  }

  /// How a walk ended. A walk stopped at a set fingerprint ends in plain success; one that
  /// ends in `DC_STATUS_PROTOCOL` with nothing new and a fingerprint set on the device is complete
  /// too, but for the Nautic family, whose backend returns that status only for a real failure. A
  /// walk that delivered nothing fails, naming `DC_STATUS_DATAFORMAT` where the walk itself
  /// succeeded, when every record it parsed was empty. The entries left out as waiting or as not
  /// downloaded are carried to the outcome.
  static func end(
    status: dc_status_t, cancelled: Bool, family: DiveComputerFamily, delivered: Int,
    emptyReads: Int, refused: Int, fingerprintSet: Bool, waiting: Int = 0, notDownloaded: Int = 0
  ) -> DiveComputerDownloadEnd {
    let kind: DiveComputerDownloadEnd.Kind
    if cancelled || status == DC_STATUS_CANCELLED {
      kind = .cancelled
    } else if status == DC_STATUS_SUCCESS || status == DC_STATUS_DONE {
      kind =
        delivered == 0 && emptyReads > 0
        ? .failed(status: LibDCNames.status(DC_STATUS_DATAFORMAT)) : .complete
    } else if status == DC_STATUS_PROTOCOL, delivered == 0, emptyReads == 0, fingerprintSet,
      family != .suuntoNautic
    {
      kind = .complete
    } else {
      kind = .failed(status: LibDCNames.status(status))
    }
    return DiveComputerDownloadEnd(
      kind, emptyReads: emptyReads, refused: refused, waiting: waiting,
      notDownloaded: notDownloaded)
  }

  // MARK: - libdivecomputer's walk

  /// `dc_device_foreach`, with the fingerprint set on the device: from the advertised name for a
  /// family that carries the serial there, else through the bridge's lookup hook once the device
  /// info arrives.
  private func walkLibrary(_ device: UnsafeMutablePointer<device_data_t>, _ handle: OpaquePointer)
    -> DiveComputerDownloadEnd
  {
    let userdata = Unmanaged.passUnretained(self).toOpaque()
    if family.advertisesSerial, let serial = computer.advertisedSerial {
      // The device info's 32-bit serial overflows this family's, so the advertised name is the
      // identity and the bridge's lookup hook, which hands over that field, is not used.
      identify(serial: serial, firmware: deviceInfoFirmware)
      if let fingerprint = lookup(family, serial)?.fingerprint {
        fingerprintSet =
          fingerprint.withUnsafeBytes {
            dc_device_set_fingerprint(
              handle, $0.bindMemory(to: UInt8.self).baseAddress, UInt32($0.count))
          } == DC_STATUS_SUCCESS
      }
    } else {
      device.pointee.fingerprint_context = userdata
      device.pointee.lookup_fingerprint = fingerprintLookup
    }
    defer {
      device.pointee.fingerprint_context = nil
      device.pointee.lookup_fingerprint = nil
    }

    if family.logsInstants { readWatchZone() }

    let poll = progressPoll(device)
    let status = dc_device_foreach(handle, diveCallback, userdata)
    poll.cancel()
    return Self.end(
      status: status, cancelled: cancel.isSet, family: family, delivered: delivered,
      emptyReads: emptyReads, refused: refused, fingerprintSet: fingerprintSet)
  }

  /// The device info arrived: the identity, and the record's fingerprint to set, as a buffer
  /// the device record keeps until the session closes it.
  fileprivate func deviceInfo(serial hex: String, size: UnsafeMutablePointer<Int>?)
    -> UnsafeMutablePointer<UInt8>?
  {
    size?.pointee = 0
    guard let number = UInt32(hex, radix: 16) else { return nil }
    let serial = family.serial(deviceInfo: number)
    identify(serial: serial, firmware: deviceInfoFirmware)
    guard let fingerprint = lookup(family, serial)?.fingerprint, !fingerprint.isEmpty,
      let buffer = malloc(fingerprint.count)?.assumingMemoryBound(to: UInt8.self)
    else { return nil }
    fingerprint.copyBytes(to: buffer, count: fingerprint.count)
    size?.pointee = fingerprint.count
    fingerprintSet = true
    return buffer
  }

  /// The firmware the device info reported, once it has.
  private var deviceInfoFirmware: String? {
    guard let device, device.pointee.have_devinfo != 0 else { return nil }
    return LibDCNames.firmware(device.pointee.devinfo.firmware, family: family)
  }

  // MARK: - Every walk's

  /// One dive's bytes, parsed and handed on; false once the walk is cancelled. An entry of the
  /// Nautic family whose profile names a sport that is not a dive, or that holds no dive at all —
  /// an empty or aborted session, ``skipsUnframed(_:family:)`` or ``skipsEmpty(_:)`` — is yielded
  /// as skipped, as a run is, so the fingerprint moves past it.
  func dive(_ bytes: Data, fingerprint: Data) -> Bool {
    guard !cancel.isSet, let device else { return false }
    if identity == nil || identity?.firmware == nil, device.pointee.have_devinfo != 0 {
      identify(
        serial: identity?.serial ?? family.serial(deviceInfo: device.pointee.devinfo.serial),
        firmware: deviceInfoFirmware)
    } else if identity == nil {
      identify(serial: computer.advertisedSerial ?? "", firmware: nil)
    }
    guard let identity else { return false }
    if Self.skipsUnframed(bytes, family: family)
      || (family == .suuntoNautic && !NauticSport.isDive(bytes))
    {
      events.yield(.skipped(fingerprint: fingerprint))
      return true
    }
    let fallback = family == .suuntoNautic ? LibDCDiveParser.fingerprintStart(fingerprint) : nil
    let reading: DownloadedDive.Reading
    switch LibDCDiveParser.parse(bytes, identity: identity, fallbackStart: fallback) {
    case .empty:
      if Self.skipsEmpty(family) {
        events.yield(.skipped(fingerprint: fingerprint))
      } else {
        emptyReads += 1
      }
      return true
    case .refused(let start, let reason):
      refused += 1
      log("refused \(fingerprint.map { String(format: "%02x", $0) }.joined()): \(reason)")
      reading = .refused(start: start)
    case .dive(let dive):
      reading = .dive(dive)
    }
    delivered += 1
    events.yield(
      .dive(
        DownloadedDive(
          identity: identity, fingerprint: fingerprint, bytes: bytes, reading: reading)))
    return true
  }

  /// Whether a reading with no samples and no duration is skipped as no dive rather than counted
  /// as an empty read: on the Nautic family it is an empty or aborted session, which the backend
  /// delivers as bytes since it leaves the content to the parser.
  static func skipsEmpty(_ family: DiveComputerFamily) -> Bool {
    family == .suuntoNautic
  }

  /// Whether bytes are skipped as no dive before they are parsed: on the Nautic family, bytes
  /// that do not open with the SBEM container's header are an empty or aborted session. Bytes
  /// that do, and that the parser refuses — a container version it does not know yet — are kept
  /// as a refused reading, which may be a dive.
  static func skipsUnframed(_ bytes: Data, family: DiveComputerFamily) -> Bool {
    family == .suuntoNautic && !bytes.starts(with: sbemHeader)
  }

  private static let sbemHeader = Data("SBEM".utf8)

  fileprivate var isCancelled: Bool { cancel.isSet }

  /// Yields the identity once known, and again where a later answer adds the firmware or the
  /// hardware.
  @discardableResult func identify(serial: String, firmware: String?, hardware: String? = nil)
    -> DiveComputerIdentity
  {
    let next = DiveComputerIdentity(
      family: family, vendor: vendor, product: product, serial: serial,
      firmware: firmware ?? identity?.firmware, hardware: hardware ?? identity?.hardware,
      familyNumber: dcFamily.rawValue, modelNumber: model)
    guard next != identity else { return next }
    identity = next
    events.yield(.identified(next))
    return next
  }

  /// The watch's zone, from the settings resources it is decoded from; one the watch refuses is
  /// left out, and the decode reads the rest. Whether a zone was read.
  @discardableResult func readWatchZone() -> Bool {
    guard let device else { return false }
    var resources: [String: Data] = [:]
    for path in NauticWatchZone.paths {
      resources[path] = try? SuuntoNauticExplorer.fetch(device: device, path: path)
    }
    guard let zone = NauticWatchZone.decode(resources) else { return false }
    events.yield(.watchZone(zone))
    return true
  }

  /// Runs `call` over a fresh libdivecomputer buffer: its status, and the bytes the buffer then
  /// holds.
  static func buffered(_ call: (OpaquePointer) -> dc_status_t) -> (dc_status_t, Data) {
    guard let buffer = dc_buffer_new(0) else { return (DC_STATUS_NOMEMORY, Data()) }
    defer { dc_buffer_free(buffer) }
    let status = call(buffer)
    let size = dc_buffer_get_size(buffer)
    guard size > 0, let data = dc_buffer_get_data(buffer) else { return (status, Data()) }
    return (status, Data(bytes: data, count: size))
  }

  /// libdivecomputer's progress, which the bridge caches on the device record rather than
  /// forwarding: its event callback is the one the device allows, and it is also the hook that
  /// sets a Shearwater's fingerprint.
  private func progressPoll(_ device: UnsafeMutablePointer<device_data_t>)
    -> any DispatchSourceTimer
  {
    nonisolated(unsafe) let device = device
    let events = events
    nonisolated(unsafe) var last: (UInt32, UInt32)?
    let timer = DispatchSource.makeTimerSource(queue: .global(qos: .userInitiated))
    timer.schedule(deadline: .now(), repeating: 0.25)
    timer.setEventHandler {
      guard device.pointee.have_progress != 0 else { return }
      let progress = device.pointee.progress
      guard last.map({ $0 != (progress.current, progress.maximum) }) ?? true else { return }
      last = (progress.current, progress.maximum)
      events.yield(.progress(current: Int(progress.current), maximum: Int(progress.maximum)))
    }
    timer.resume()
    return timer
  }
}

private nonisolated func walk(_ userdata: UnsafeMutableRawPointer?) -> LibDCWalk? {
  userdata.map { Unmanaged<LibDCWalk>.fromOpaque($0).takeUnretainedValue() }
}

private nonisolated let diveCallback:
  @convention(c) (
    UnsafePointer<UInt8>?, UInt32, UnsafePointer<UInt8>?, UInt32, UnsafeMutableRawPointer?
  ) -> Int32 = { data, size, fingerprint, fsize, userdata in
    guard let walk = walk(userdata), let data else { return 0 }
    let bytes = Data(bytes: data, count: Int(size))
    let print = fingerprint.map { Data(bytes: $0, count: Int(fsize)) } ?? Data()
    return walk.dive(bytes, fingerprint: print) ? 1 : 0
  }

private nonisolated let cancelCallback: @convention(c) (UnsafeMutableRawPointer?) -> Int32 = {
  walk($0)?.isCancelled == true ? 1 : 0
}

private nonisolated let fingerprintLookup:
  @convention(c) (
    UnsafeMutableRawPointer?, UnsafePointer<CChar>?, UnsafePointer<CChar>?,
    UnsafeMutablePointer<Int>?
  ) -> UnsafeMutablePointer<UInt8>? = { userdata, _, serial, size in
    guard let walk = walk(userdata), let serial else { return nil }
    return walk.deviceInfo(serial: String(cString: serial), size: size)
  }
