@preconcurrency import Clibdivecomputer
import Foundation
import OpenDivingKit

/// A Shearwater Petrel-family computer, walked as `shearwater_petrel_device_foreach` walks it but
/// with the whole manifest read first, so the count comes before the first dive: the identity by
/// identifier, every manifest page, then each new dive. One connection, since a Perdix 3 answers a
/// second manifest read on it with an all-zero index.
nonisolated extension LibDCWalk {
  func walkPetrel(_ handle: OpaquePointer) -> DiveComputerDownloadEnd {
    let fingerprint: Data?
    let base: UInt32
    switch petrelIdentity(handle) {
    case .failure(let failure): return petrelEnd(failure.status)
    case .success(let found):
      identify(serial: found.serial, firmware: found.firmware)
      fingerprint = lookup(family, found.serial)?.fingerprintToSet
      base = found.logBase
    }

    var records: [PetrelManifest.Record] = []
    while true {
      let (status, bytes) = Self.buffered {
        shearwaterCommonDownload(
          handle, $0, PetrelManifest.address, UInt32(PetrelManifest.pageSize), 0, nil)
      }
      guard status == DC_STATUS_SUCCESS else { return petrelEnd(status) }
      let page = PetrelManifest.Page(bytes)
      records += page.records
      if !page.continues { break }
    }

    let selection = PetrelManifest.select(records, fingerprint: fingerprint)
    events.yield(.listing(selection.listing))
    for record in selection.new {
      if cancel.isSet { break }
      let (status, bytes) = Self.buffered {
        shearwaterCommonDownload(handle, $0, base &+ record.address, Self.petrelDiveSize, 1, nil)
      }
      guard status == DC_STATUS_SUCCESS else { return petrelEnd(status) }
      // The start the dive's own header carries, as libdivecomputer's walk hands it on.
      guard dive(bytes, fingerprint: Data(bytes.dropFirst(12).prefix(4))) else { break }
    }
    return petrelEnd(DC_STATUS_SUCCESS)
  }

  /// The most a dive's download may read, libdivecomputer's `DIVE_SIZE`: the computer stops at
  /// the dive's end.
  static let petrelDiveSize: UInt32 = 0xFF_FFFF

  private struct PetrelIdentity {
    let serial: String
    let firmware: String?
    let logBase: UInt32
  }

  /// The serial, the firmware and the log format's base address, read by identifier, decoded as
  /// libdivecomputer's walk decodes them; `DC_STATUS_DATAFORMAT` where the serial or the log
  /// format is one libdivecomputer refuses too.
  private func petrelIdentity(_ handle: OpaquePointer) -> Result<PetrelIdentity, PetrelFailure> {
    var serial = [UInt8](repeating: 0, count: 8)
    var firmware = [UInt8](repeating: 0, count: 12)
    var firmwareLength: UInt32 = 0
    var logFormat = [UInt8](repeating: 0, count: 9)
    var status = shearwaterCommonRDBI(
      handle, UInt32(PetrelIdentifier.serial), &serial, UInt32(serial.count), nil)
    if status == DC_STATUS_SUCCESS {
      status = shearwaterCommonRDBI(
        handle, UInt32(PetrelIdentifier.firmware), &firmware, UInt32(firmware.count),
        &firmwareLength)
    }
    if status == DC_STATUS_SUCCESS {
      status = shearwaterCommonRDBI(
        handle, UInt32(PetrelIdentifier.logFormat), &logFormat, UInt32(logFormat.count), nil)
    }
    guard status == DC_STATUS_SUCCESS else { return .failure(PetrelFailure(status)) }
    guard let decoded = PetrelIdentifier.serial(Data(serial)),
      let logBase = PetrelIdentifier.logBase(Data(logFormat))
    else { return .failure(PetrelFailure(DC_STATUS_DATAFORMAT)) }
    let number = PetrelIdentifier.firmware(Data(firmware.prefix(Int(firmwareLength))))
    return .success(
      PetrelIdentity(
        serial: decoded, firmware: LibDCNames.firmware(number, family: family),
        logBase: logBase))
  }

  /// The walk compares the fingerprint itself and never reads past it, so libdivecomputer's
  /// leniency for a walk stopped at a fingerprint set on the device does not apply.
  private func petrelEnd(_ status: dc_status_t) -> DiveComputerDownloadEnd {
    Self.end(
      status: status, cancelled: cancel.isSet, family: family, delivered: delivered,
      emptyReads: emptyReads, refused: refused, fingerprintSet: false)
  }
}

private struct PetrelFailure: Error {
  let status: dc_status_t

  init(_ status: dc_status_t) {
    self.status = status
  }
}
