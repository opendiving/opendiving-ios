import Foundation

/// A Shearwater Petrel-family computer's answers to *read data by identifier*, decoded as
/// libdivecomputer's walk decodes them.
public enum PetrelIdentifier {
  /// Eight ASCII hex digits.
  public static let serial: UInt16 = 0x8010
  /// ASCII: `V39 Classic`.
  public static let firmware: UInt16 = 0x8011
  /// The log format; bytes 1 to 4 are its base address.
  public static let logFormat: UInt16 = 0x8021
  /// One byte: libdivecomputer's model number.
  public static let model: UInt16 = 0x8060

  /// The serial as ``DiveComputerFamily/serial(deviceInfo:)`` spells the same computer's device
  /// info: `D9772626`. Nil where the answer is not eight hex digits, which libdivecomputer
  /// refuses too.
  public static func serial(_ answer: Data) -> String? {
    let digits = String(decoding: answer, as: UTF8.self)
    guard answer.count == 8, digits.allSatisfy(\.isHexDigit), let number = UInt32(digits, radix: 16)
    else { return nil }
    return DiveComputerFamily.shearwaterPetrel.serial(deviceInfo: number)
  }

  /// The firmware number libdivecomputer reports: the digits from the second character, `39`
  /// for `V39 Classic`, and 0 where there are none.
  public static func firmware(_ answer: Data) -> UInt32 {
    var value: UInt32 = 0
    for byte in answer.dropFirst() {
      guard (0x30...0x39).contains(byte) else { break }
      value = value &* 10 &+ UInt32(byte - 0x30)
    }
    return value
  }

  /// The address the log format's dives are read from, by libdivecomputer's table: the
  /// Predator-like formats at `0xC0000000`, the Petrel native format at `0x80000000`. Nil for a
  /// format the table does not know.
  public static func logBase(_ answer: Data) -> UInt32? {
    let data = [UInt8](answer)
    guard data.count >= 5 else { return nil }
    switch data[1..<5].reduce(UInt32(0), { $0 << 8 | UInt32($1) }) {
    case 0xDD00_0000, 0xC000_0000, 0x9000_0000: return 0xC000_0000
    case 0x8000_0000: return 0x8000_0000
    default: return nil
    }
  }
}
