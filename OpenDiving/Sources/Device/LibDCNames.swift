@preconcurrency import Clibdivecomputer
import Foundation
@preconcurrency import LibDCSwift
import OpenDivingKit

/// What libdivecomputer calls things, in the Kit's words: a computer's family and model from
/// the name it advertises, the Kit's family name for `dc_family_t`, a status by name.
nonisolated enum LibDCNames {
  /// A computer resolved from its advertised name.
  struct Resolved: Hashable, Sendable {
    var family: DiveComputerFamily
    var vendor: String
    var product: String
    var model: UInt32
  }

  /// The found computer for a peripheral advertising `name`.
  static func found(name: String, id: UUID) -> FoundComputer {
    let resolved = resolve(name)
    return FoundComputer(
      id: id, name: name, family: resolved?.family, vendor: resolved?.vendor,
      product: resolved?.product, modelNumber: resolved?.model)
  }

  /// An advertised name equal, folding case, to the product of one of libdivecomputer's
  /// Bluetooth descriptors is that product. libdc-swift's own lookup matches by substring over
  /// a table with no *Perdix 3* row, which would open a Perdix 3 as a Perdix and talk the wrong
  /// wire protocol to it; its inference is taken only for a name no product equals, such as a
  /// Nautic's, which carries the serial after the product.
  static func resolve(_ name: String) -> Resolved? {
    let trimmed = name.trimmingCharacters(in: .whitespaces)
    if let exact = descriptors().first(where: {
      $0.product.caseInsensitiveCompare(trimmed) == .orderedSame
    }) {
      return exact
    }
    guard let inferred = DeviceConfiguration.fromName(trimmed) else { return nil }
    return descriptors().first {
      $0.family == family(inferred.family.asDCFamily) && $0.model == inferred.model
    }
  }

  /// libdivecomputer's descriptors that speak Bluetooth Low Energy.
  static func descriptors() -> [Resolved] {
    var iterator: OpaquePointer?
    guard dc_descriptor_iterator_new(&iterator, nil) == DC_STATUS_SUCCESS, let iterator else {
      return []
    }
    defer { dc_iterator_free(iterator) }
    var found: [Resolved] = []
    var descriptor: OpaquePointer?
    while dc_iterator_next(iterator, &descriptor) == DC_STATUS_SUCCESS, let current = descriptor {
      defer { dc_descriptor_free(current) }
      guard dc_descriptor_get_transports(current) & DC_TRANSPORT_BLE.rawValue != 0,
        let vendor = dc_descriptor_get_vendor(current),
        let product = dc_descriptor_get_product(current)
      else { continue }
      found.append(
        Resolved(
          family: family(dc_descriptor_get_type(current)), vendor: String(cString: vendor),
          product: String(cString: product), model: dc_descriptor_get_model(current)))
    }
    return found
  }

  /// The Kit's name for a libdivecomputer family: libdc-swift's family name in kebab case,
  /// `shearwater-petrel`, so the two the Kit names agree with it.
  static func family(_ family: dc_family_t) -> DiveComputerFamily {
    guard let known = DeviceConfiguration.DeviceFamily(dcFamily: family) else {
      return DiveComputerFamily(rawValue: "libdivecomputer-\(family.rawValue)")
    }
    return DiveComputerFamily(rawValue: kebab(known.rawValue))
  }

  /// libdivecomputer's family for the Kit's name, at the pinned library: what the open uses.
  static func dcFamily(_ family: DiveComputerFamily) -> dc_family_t? {
    DeviceConfiguration.DeviceFamily.allCases.first { kebab($0.rawValue) == family.rawValue }?
      .asDCFamily
  }

  private static func kebab(_ camel: String) -> String {
    camel.reduce(into: "") { name, character in
      if character.isUppercase {
        name += "-" + character.lowercased()
      } else {
        name.append(character)
      }
    }
  }

  /// A firmware version as the family's exports spell it: a Nautic's packed `a.b.c`, the
  /// number otherwise; nil where the device reported none.
  static func firmware(_ firmware: UInt32, family: DiveComputerFamily) -> String? {
    guard firmware != 0 else { return nil }
    guard family == .suuntoNautic else { return String(firmware) }
    return "\(firmware >> 16).\((firmware >> 8) & 0xFF).\(firmware & 0xFF)"
  }

  /// `DC_STATUS_PROTOCOL`.
  static func status(_ status: dc_status_t) -> String {
    switch status {
    case DC_STATUS_SUCCESS: "DC_STATUS_SUCCESS"
    case DC_STATUS_DONE: "DC_STATUS_DONE"
    case DC_STATUS_UNSUPPORTED: "DC_STATUS_UNSUPPORTED"
    case DC_STATUS_INVALIDARGS: "DC_STATUS_INVALIDARGS"
    case DC_STATUS_NOMEMORY: "DC_STATUS_NOMEMORY"
    case DC_STATUS_NODEVICE: "DC_STATUS_NODEVICE"
    case DC_STATUS_NOACCESS: "DC_STATUS_NOACCESS"
    case DC_STATUS_IO: "DC_STATUS_IO"
    case DC_STATUS_TIMEOUT: "DC_STATUS_TIMEOUT"
    case DC_STATUS_PROTOCOL: "DC_STATUS_PROTOCOL"
    case DC_STATUS_DATAFORMAT: "DC_STATUS_DATAFORMAT"
    case DC_STATUS_CANCELLED: "DC_STATUS_CANCELLED"
    default: "DC_STATUS(\(status.rawValue))"
    }
  }
}
