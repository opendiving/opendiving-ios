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
}
