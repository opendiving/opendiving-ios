@preconcurrency import Clibdivecomputer
import Foundation
@preconcurrency import LibDCBridge
@preconcurrency import LibDCSwift
import OpenDivingKit

/// One walk over an open device: the identity, the fingerprint set before any dive is read,
/// the watch's zone for a family that logs instants, then each dive's bytes parsed as they
/// arrive, and the outcome. Its instance is the userdata of libdivecomputer's callbacks, all of
/// which run on the session's queue but the progress poll's.
nonisolated final class LibDCWalk: @unchecked Sendable {
  private let computer: FoundComputer
  private let device: UnsafeMutablePointer<device_data_t>
  private let cancel: CancelFlag
  private let lookup: @Sendable (DiveComputerFamily, String) -> DiveComputerRecord?
  private let events: AsyncStream<DiveComputerDownloadEvent>.Continuation

  private let family: DiveComputerFamily
  private let dcFamily: dc_family_t
  private let model: UInt32
  private let vendor: String
  private let product: String

  private var identity: DiveComputerIdentity?
  private var fingerprintSet = false
  private var delivered = 0
  private var emptyReads = 0
  private var refused = 0

  init(
    computer: FoundComputer, device: UnsafeMutablePointer<device_data_t>, cancel: CancelFlag,
    lookup: @escaping @Sendable (DiveComputerFamily, String) -> DiveComputerRecord?,
    events: AsyncStream<DiveComputerDownloadEvent>.Continuation
  ) {
    self.computer = computer
    self.device = device
    self.cancel = cancel
    self.lookup = lookup
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
    guard let handle = device.pointee.device else {
      return .init(.failed(status: LibDCNames.status(DC_STATUS_NODEVICE)))
    }
    let userdata = Unmanaged.passUnretained(self).toOpaque()
    clearFingerprint(handle)

    if family.advertisesSerial, let serial = computer.advertisedSerial {
      // The device info's 32-bit serial overflows this family's, so the advertised name is the
      // identity and the bridge's lookup hook, which hands over that field, is not used.
      identify(serial: serial)
      if let fingerprint = lookup(family, serial)?.fingerprintToSet {
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
      dc_device_set_cancel(handle, nil, nil)
    }

    if family.logsInstants {
      let resources = NauticZoneResources.fetch(device)
      if NauticZoneCapture.isEnabled {
        NauticZoneCapture.write(resources, computer: computer)
        return .init(.cancelled)
      }
    }

    dc_device_set_cancel(handle, cancelCallback, userdata)
    let poll = progressPoll()
    let status = dc_device_foreach(handle, diveCallback, userdata)
    poll.cancel()
    return Self.end(
      status: status, cancelled: cancel.isSet, family: family, delivered: delivered,
      emptyReads: emptyReads, refused: refused, fingerprintSet: fingerprintSet)
  }

  /// How a walk ended. A walk stopped at a set fingerprint ends in plain success; one that
  /// ends in `DC_STATUS_PROTOCOL` with nothing new and a fingerprint set is complete too, but
  /// for the Nautic family, whose backend returns that status only for a real failure. A walk
  /// whose every record was empty failed, naming `DC_STATUS_DATAFORMAT` where the walk itself
  /// succeeded.
  static func end(
    status: dc_status_t, cancelled: Bool, family: DiveComputerFamily, delivered: Int,
    emptyReads: Int, refused: Int, fingerprintSet: Bool
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
    return DiveComputerDownloadEnd(kind, emptyReads: emptyReads, refused: refused)
  }

  // MARK: - The callbacks' work

  /// The device info arrived: the identity, and the record's fingerprint to set, as a buffer
  /// the bridge frees.
  fileprivate func deviceInfo(serial hex: String, size: UnsafeMutablePointer<Int>?)
    -> UnsafeMutablePointer<UInt8>?
  {
    size?.pointee = 0
    guard let number = UInt32(hex, radix: 16) else { return nil }
    let serial = family.serial(deviceInfo: number)
    identify(serial: serial)
    guard let fingerprint = lookup(family, serial)?.fingerprintToSet, !fingerprint.isEmpty,
      let buffer = malloc(fingerprint.count)?.assumingMemoryBound(to: UInt8.self)
    else { return nil }
    fingerprint.copyBytes(to: buffer, count: fingerprint.count)
    // The bridge keeps the buffer on the device record; the one a previous walk handed it is
    // released here, since it frees only the last.
    free(device.pointee.fingerprint)
    device.pointee.fingerprint = nil
    device.pointee.fsize = 0
    size?.pointee = fingerprint.count
    fingerprintSet = true
    return buffer
  }

  fileprivate func dive(_ bytes: Data, fingerprint: Data) -> Bool {
    if cancel.isSet { return false }
    if identity == nil || identity?.firmware == nil, device.pointee.have_devinfo != 0 {
      identify(serial: identity?.serial ?? family.serial(deviceInfo: device.pointee.devinfo.serial))
    } else if identity == nil {
      identify(serial: computer.advertisedSerial ?? "")
    }
    guard let identity else { return false }
    let fallback = family == .suuntoNautic ? LibDCDiveParser.fingerprintStart(fingerprint) : nil
    let reading: DownloadedDive.Reading
    switch LibDCDiveParser.parse(
      bytes, context: device.pointee.context, family: dcFamily, model: model,
      logsInstants: family.logsInstants, fallbackStart: fallback)
    {
    case .empty:
      emptyReads += 1
      return true
    case .refused(let start):
      refused += 1
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

  fileprivate var isCancelled: Bool { cancel.isSet }

  // MARK: - Pieces

  /// Yields the identity once known, and again where the device info later adds the firmware.
  private func identify(serial: String) {
    let firmware =
      device.pointee.have_devinfo != 0
      ? LibDCNames.firmware(device.pointee.devinfo.firmware, family: family) : nil
    let next = DiveComputerIdentity(
      family: family, vendor: vendor, product: product, serial: serial,
      firmware: firmware ?? identity?.firmware, familyNumber: dcFamily.rawValue,
      modelNumber: model)
    guard next != identity else { return }
    identity = next
    events.yield(.identified(next))
  }

  /// Clears what an earlier walk on the same device set, so a walk sets only what its own
  /// lookup returns.
  private func clearFingerprint(_ handle: OpaquePointer) {
    dc_device_set_fingerprint(handle, nil, 0)
    free(device.pointee.fingerprint)
    device.pointee.fingerprint = nil
    device.pointee.fsize = 0
  }

  /// libdivecomputer's progress, which the bridge caches on the device record rather than
  /// forwarding: its event callback is the one the device allows, and it is also the hook that
  /// sets a Shearwater's fingerprint.
  private func progressPoll() -> any DispatchSourceTimer {
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
