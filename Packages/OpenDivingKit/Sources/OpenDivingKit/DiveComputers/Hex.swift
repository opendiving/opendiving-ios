import Foundation

extension UInt32 {
  func rotatedRight(_ n: UInt32) -> UInt32 { (self >> n) | (self << (32 - n)) }
  func rotatedLeft(_ n: UInt32) -> UInt32 { (self << n) | (self >> (32 - n)) }
}

/// Bytes as hex digits.
enum Hex {
  private static let digits = Array("0123456789abcdef".utf8)

  static func lowercase(_ bytes: some Sequence<UInt8>) -> String {
    var out: [UInt8] = []
    for byte in bytes {
      out.append(digits[Int(byte >> 4)])
      out.append(digits[Int(byte & 0x0F)])
    }
    return String(decoding: out, as: UTF8.self)
  }

  /// Hex digits as bytes, either case; nil for anything else.
  static func data(_ text: String) -> Data? {
    let scalars = Array(text.utf8)
    guard scalars.count % 2 == 0 else { return nil }
    var out = Data(capacity: scalars.count / 2)
    var index = 0
    while index < scalars.count {
      guard let high = nibble(scalars[index]), let low = nibble(scalars[index + 1]) else {
        return nil
      }
      out.append(high << 4 | low)
      index += 2
    }
    return out
  }

  private static func nibble(_ digit: UInt8) -> UInt8? {
    switch digit {
    case UInt8(ascii: "0")...UInt8(ascii: "9"): digit - UInt8(ascii: "0")
    case UInt8(ascii: "a")...UInt8(ascii: "f"): digit - UInt8(ascii: "a") + 10
    case UInt8(ascii: "A")...UInt8(ascii: "F"): digit - UInt8(ascii: "A") + 10
    default: nil
    }
  }
}
