import Foundation

/// A family of dive computers as the Kit names it: the name a remembered computer is kept
/// under, a dive's uuid is derived from and the conformance maps to libdivecomputer's family
/// at the open. Never `dc_family_t`'s number, which libdc-swift's fork assigns ahead of
/// upstream and a pin move could change.
///
/// The families this phase is built for are named here; every other family libdivecomputer
/// opens gets a name of the conformance's choosing, and the rules below take their defaults.
public struct DiveComputerFamily: RawRepresentable, Hashable, Codable, Sendable {
  public let rawValue: String

  public init(rawValue: String) {
    self.rawValue = rawValue
  }

  /// libdivecomputer's Shearwater Petrel family: the Petrel 2 and later, the Perdix, the
  /// Teric, the Peregrine, the Tern.
  public static let shearwaterPetrel = DiveComputerFamily(rawValue: "shearwater-petrel")
  /// libdivecomputer's Suunto Nautic family: the Nautic and the Ocean.
  public static let suuntoNautic = DiveComputerFamily(rawValue: "suunto-nautic")

  /// Whether the family logs a dive's start as an instant with no local clock, so a download
  /// needs a zone to write it in.
  public var logsInstants: Bool { self == .suuntoNautic }

  /// Whether the computer's advertised name carries its serial after the product, which is
  /// the serial its owner's exports spell.
  public var advertisesSerial: Bool { self == .suuntoNautic }

  /// The device block's `model`, spelled as the family's primary export spells it so the
  /// api's device test matches the recordings those exports made: the product alone for the
  /// Petrel family (*Perdix 3*, as Shearwater Cloud's UDDF writes it), vendor and product
  /// joined for the Nautic family (*Suunto Ocean*, as the Suunto app's FIT writes it), and
  /// vendor and product joined for a family no export has been read for.
  public func deviceModel(vendor: String, product: String) -> String {
    let vendor = vendor.trimmingCharacters(in: .whitespacesAndNewlines)
    let product = product.trimmingCharacters(in: .whitespacesAndNewlines)
    if self == .shearwaterPetrel || vendor.isEmpty { return product }
    return vendor + " " + product
  }

  /// A serial as the device info reports it, spelled as this family's exports spell it: eight
  /// uppercase hex digits for a Shearwater (`D9772626`), which is also what the computer's own
  /// screen shows; the decimal number otherwise. A Nautic's serial overflows this field and
  /// comes from ``serial(advertisedIn:)`` instead.
  public func serial(deviceInfo serial: UInt32) -> String {
    guard self == .shearwaterPetrel else { return String(serial) }
    let hex = String(serial, radix: 16, uppercase: true)
    return String(repeating: "0", count: 8 - hex.count) + hex
  }

  /// The serial an advertised name carries after the product, for a family that advertises
  /// one: `253810000400` in *Suunto Ocean 253810000400*. Nil for any other family, and for a
  /// name with nothing after its first word.
  public func serial(advertisedIn name: String) -> String? {
    guard advertisesSerial else { return nil }
    let words = name.split(whereSeparator: \.isWhitespace)
    guard words.count > 1, let last = words.last,
      last.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber) })
    else { return nil }
    return String(last)
  }
}
